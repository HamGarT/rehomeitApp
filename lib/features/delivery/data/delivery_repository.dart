import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_errors.dart';
import '../../../core/firebase/firestore_commit.dart';
import '../../../shared/data/notification_payload.dart';
import '../../../shared/domain/publication.dart';
import '../../messaging/data/messaging_repository.dart';
import '../domain/delivery_draft.dart';
import 'pending_delivery_store.dart';

final deliveryRepositoryProvider = Provider<DeliveryRepository>((ref) {
  return DeliveryRepository(
    FirebaseFirestore.instance,
    FirebaseStorage.instance,
    PendingDeliveryStore(),
  );
});

class DeliveryRepository {
  DeliveryRepository(this._firestore, this._storage, this._pendingStore);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final PendingDeliveryStore _pendingStore;

  Stream<List<Publication>> watchCommitments(String volunteerId) {
    return _firestore
        .collection('publicaciones')
        .where('volunteerId', isEqualTo: volunteerId)
        .where(
          'status',
          whereIn: [
            PublicationStatus.committed.wireValue,
            PublicationStatus.pickedUp.wireValue,
          ],
        )
        .orderBy('committedAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Publication.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  Future<void> assumePickup({
    required Publication publication,
    required String volunteerId,
  }) async {
    final publicationRef = _firestore
        .collection('publicaciones')
        .doc(publication.id);
    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(publicationRef);
        if (!snapshot.exists) {
          throw const DeliveryFailure('La publicación ya no existe.');
        }
        final current = Publication.fromMap(snapshot.id, snapshot.data()!);
        if (current.authorId == volunteerId) {
          throw const DeliveryFailure('No puedes asumir tu propio recojo.');
        }
        if (current.mode != PublicationMode.donation ||
            current.deliveryType != DeliveryType.volunteer ||
            current.status != PublicationStatus.published) {
          throw const DeliveryFailure(
            'Este bien ya no está disponible para recojo.',
          );
        }
        transaction.update(publicationRef, {
          'status': PublicationStatus.committed.wireValue,
          'volunteerId': volunteerId,
          'committedAt': FieldValue.serverTimestamp(),
          'statusDates.${PublicationStatus.committed.wireValue}':
              FieldValue.serverTimestamp(),
        });

        final conversationId = MessagingRepository.conversationId(
          publicationId: current.id,
          firstUserId: current.authorId,
          secondUserId: volunteerId,
        );
        final conversationRef = _firestore
            .collection('conversaciones')
            .doc(conversationId);
        final conversation = await transaction.get(conversationRef);
        if (!conversation.exists) {
          final participants = [current.authorId, volunteerId]..sort();
          transaction.set(conversationRef, {
            'publicationId': current.id,
            'publicationTitle': current.title,
            'publicationImageUrl': current.images.isEmpty
                ? null
                : current.images.first,
            'publicationMode': current.mode.wireValue,
            'participantIds': participants,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'lastMessage': '',
            'lastSenderId': null,
            'lastMessageId': null,
          });
        }
        transaction.set(
          _firestore.collection('notificaciones').doc(),
          notificationPayload(
            recipientId: current.authorId,
            type: 'recojo_asumido',
            message: 'Un usuario asumió el recojo de ${current.title}.',
            publicationId: current.id,
            actorId: volunteerId,
          ),
        );
      });
    } on DeliveryFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw DeliveryFailure(_friendlyFirebaseMessage(error));
    }
  }

  Future<void> releaseCommitment({
    required Publication publication,
    required String actorId,
  }) async {
    final isOwner = actorId == publication.authorId;
    final recipientId = isOwner
        ? publication.volunteerId
        : publication.authorId;
    if (recipientId == null) {
      throw const DeliveryFailure('No existe un compromiso activo.');
    }
    final publicationRef = _firestore
        .collection('publicaciones')
        .doc(publication.id);
    final batch = _firestore.batch();
    batch.update(publicationRef, {
      'status': PublicationStatus.published.wireValue,
      'volunteerId': FieldValue.delete(),
      'committedAt': FieldValue.delete(),
    });
    batch.set(
      _firestore.collection('notificaciones').doc(),
      notificationPayload(
        recipientId: recipientId,
        type: 'compromiso_liberado',
        message: isOwner
            ? 'El donante canceló el compromiso de ${publication.title}; el bien volvió a estar disponible.'
            : 'El voluntario desistió del recojo de ${publication.title}; el bien volvió a estar disponible.',
        publicationId: publication.id,
        actorId: actorId,
      ),
    );
    try {
      await commitOfflineTolerant(batch);
    } on FirebaseException catch (error) {
      throw DeliveryFailure(_friendlyFirebaseMessage(error));
    }
  }

  Future<void> confirmHandoff({
    required Publication publication,
    required String ownerId,
  }) async {
    final volunteerId = publication.volunteerId;
    if (volunteerId == null || publication.authorId != ownerId) {
      throw const DeliveryFailure('No puedes confirmar esta entrega.');
    }
    final publicationRef = _firestore
        .collection('publicaciones')
        .doc(publication.id);
    final batch = _firestore.batch();
    batch.update(publicationRef, {
      'status': PublicationStatus.pickedUp.wireValue,
      'pickedUpAt': FieldValue.serverTimestamp(),
      'statusDates.${PublicationStatus.pickedUp.wireValue}':
          FieldValue.serverTimestamp(),
    });
    // Id fijo: si el lote se reintenta sin conexión no se duplica el aviso.
    batch.set(
      _firestore
          .collection('notificaciones')
          .doc('entrega_voluntario_${publication.id}'),
      notificationPayload(
        recipientId: volunteerId,
        type: 'entrega_a_voluntario',
        message: 'El donante confirmó la entrega de ${publication.title}.',
        publicationId: publication.id,
        actorId: ownerId,
      ),
    );
    try {
      await commitOfflineTolerant(batch);
    } on FirebaseException catch (error) {
      throw DeliveryFailure(_friendlyFirebaseMessage(error));
    }
  }

  Future<void> confirmClose({
    required Publication publication,
    required String ownerId,
  }) async {
    final volunteerId = publication.volunteerId;
    if (volunteerId == null ||
        !publication.canConfirmClose(ownerId, DateTime.now())) {
      throw const DeliveryFailure('No puedes confirmar el cierre.');
    }
    final publicationRef = _firestore
        .collection('publicaciones')
        .doc(publication.id);
    final batch = _firestore.batch();
    batch.update(publicationRef, {
      'status': PublicationStatus.confirmed.wireValue,
      'statusDates.${PublicationStatus.confirmed.wireValue}':
          FieldValue.serverTimestamp(),
    });
    batch.set(
      _firestore
          .collection('notificaciones')
          .doc('cierre_confirmado_${publication.id}'),
      notificationPayload(
        recipientId: volunteerId,
        type: 'cierre_confirmado',
        message: 'El donante confirmó el cierre de ${publication.title}.',
        publicationId: publication.id,
        actorId: ownerId,
      ),
    );
    try {
      await commitOfflineTolerant(batch);
    } on FirebaseException catch (error) {
      throw DeliveryFailure(_friendlyFirebaseMessage(error));
    }
  }

  Future<String> evidenceUrl(String storagePath) {
    return _storage.ref(storagePath).getDownloadURL();
  }

  Future<DeliverySubmissionResult> registerDelivery({
    required Publication publication,
    required String userId,
    required DeliveryDraft draft,
  }) async {
    final isDirect = publication.deliveryType == DeliveryType.owner;
    final authorized =
        publication.mode == PublicationMode.donation &&
        ((isDirect &&
                publication.authorId == userId &&
                publication.status == PublicationStatus.published) ||
            (!isDirect &&
                publication.volunteerId == userId &&
                publication.status == PublicationStatus.pickedUp));
    if (!authorized) {
      throw const DeliveryFailure(
        'No puedes registrar la entrega en el estado actual.',
      );
    }
    final validation = draft.validate();
    if (validation != null) throw DeliveryFailure(validation);
    final pending = await _pendingStore.save(
      publicationId: publication.id,
      userId: userId,
      recipientInitials: draft.normalizedInitials,
      district: draft.district!,
      photo: draft.photo!,
      isDirect: isDirect,
    );
    try {
      await _synchronize(pending);
      return DeliverySubmissionResult.synchronized;
    } on FirebaseException catch (error) {
      if (isOfflineFirebaseError(error)) {
        return DeliverySubmissionResult.pending;
      }
      throw DeliveryFailure(_friendlyFirebaseMessage(error));
    } on TimeoutException {
      return DeliverySubmissionResult.pending;
    } on SocketException {
      return DeliverySubmissionResult.pending;
    }
  }

  Future<int> synchronizePending(String userId) async {
    final pending = await _pendingStore.readAll(userId: userId);
    var synchronized = 0;
    for (final operation in pending) {
      try {
        await _synchronize(operation);
        synchronized++;
      } catch (_) {
        // Se conserva para el siguiente inicio, reanudación o reintento.
      }
    }
    return synchronized;
  }

  Future<int> pendingCount(String userId) async {
    return (await _pendingStore.readAll(userId: userId)).length;
  }

  Future<void> _synchronize(PendingDelivery pending) async {
    final photo = File(pending.localPhotoPath);
    if (!await photo.exists()) {
      throw const DeliveryFailure(
        'La fotografía pendiente ya no está disponible en el dispositivo.',
      );
    }
    final storagePath =
        'entregas/${pending.publicationId}/${pending.userId}/evidencia.${pending.extension}';
    final evidenceRef = _storage.ref(storagePath);
    var exists = false;
    try {
      await evidenceRef.getMetadata();
      exists = true;
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
    if (!exists) {
      final upload = evidenceRef.putFile(
        photo,
        SettableMetadata(contentType: pending.contentType),
      );
      try {
        await upload.timeout(const Duration(seconds: 25));
      } on TimeoutException {
        await upload.cancel();
        rethrow;
      }
    }

    final targetStatus = pending.isDirect
        ? PublicationStatus.confirmed
        : PublicationStatus.delivered;
    final publicationRef = _firestore
        .collection('publicaciones')
        .doc(pending.publicationId);
    final snapshot = await publicationRef.get();
    final data = snapshot.data();
    if (data == null) {
      throw const DeliveryFailure('La publicación ya no existe.');
    }
    final currentStatus = data['status'] as String?;
    final currentEvidence = data['deliveryEvidence'];
    if (currentStatus == targetStatus.wireValue &&
        currentEvidence is Map &&
        currentEvidence['storagePath'] == storagePath) {
      await _pendingStore.remove(pending);
      return;
    }
    final authorId = data['authorId'] as String?;
    final batch = _firestore.batch();
    batch.update(publicationRef, {
      'status': targetStatus.wireValue,
      'deliveredAt': FieldValue.serverTimestamp(),
      'statusDates.${targetStatus.wireValue}': FieldValue.serverTimestamp(),
      'deliveryEvidence': {
        'recipientInitials': pending.recipientInitials,
        'district': pending.district,
        'storagePath': storagePath,
        'recordedAt': FieldValue.serverTimestamp(),
      },
    });
    if (!pending.isDirect) {
      if (authorId == null) {
        throw const DeliveryFailure('La publicación no tiene propietario.');
      }
      batch.set(
        _firestore
            .collection('notificaciones')
            .doc('entrega_destinatario_${pending.publicationId}'),
        notificationPayload(
          recipientId: authorId,
          type: 'entrega_destinatario',
          message: 'La entrega al destinatario fue registrada. Podrás confirmar el cierre cuando esa opción esté habilitada.',
          publicationId: pending.publicationId,
          actorId: pending.userId,
        ),
      );
    }
    await batch.commit();
    await _pendingStore.remove(pending);
  }
}

class DeliveryFailure implements Exception {
  const DeliveryFailure(this.message);

  final String message;
}

String _friendlyFirebaseMessage(FirebaseException error) {
  if (isOfflineFirebaseError(error)) {
    return 'Sin conexión. La operación se conservará para reintentarse.';
  }
  if (isPermissionFirebaseError(error)) {
    return 'La operación no está permitida para el estado actual del bien.';
  }
  return 'No se pudo completar la operación (${error.code}).';
}
