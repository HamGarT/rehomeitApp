import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_errors.dart';
import '../../../core/firebase/firestore_commit.dart';
import '../../../shared/domain/publication.dart';
import '../domain/publish_draft.dart';
import 'pending_publication_store.dart';

final publishingRepositoryProvider = Provider<PublishingRepository>((ref) {
  return PublishingRepository(
    FirebaseFirestore.instance,
    FirebaseStorage.instance,
    PendingPublicationStore(),
  );
});

enum PublishSubmissionResult { synchronized, pending }

class PublishingRepository {
  PublishingRepository(this._firestore, this._storage, this._pendingStore);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final PendingPublicationStore _pendingStore;

  /// Sin red, Storage reintenta la subida hasta 10 minutos antes de fallar y
  /// el botón giraría todo ese tiempo. Mismo corte que las entregas
  /// (HU03-19, D03).
  static const _uploadTimeout = Duration(seconds: 25);

  /// Consultar metadatos o la URL de descarga reintenta hasta 2 minutos sin
  /// red; un corte corto deja la publicación pendiente en vez de bloquear.
  static const _storageLookupTimeout = Duration(seconds: 8);

  /// Guarda la publicación en el dispositivo y la sube si hay red. Si no la
  /// hay, queda pendiente y `synchronizePending` la termina al reconectar.
  Future<PublishSubmissionResult> publish({
    required PublishDraft draft,
    required String authorId,
  }) async {
    if (draft.photos.isEmpty ||
        !draft.formCompleted ||
        !draft.modeCompleted ||
        authorId.isEmpty) {
      throw const PublishingFailure(
        'Revisa los datos obligatorios antes de publicar.',
      );
    }

    final pending = await _pendingStore.save(
      publicationId: _firestore.collection('publicaciones').doc().id,
      authorId: authorId,
      draft: draft,
    );
    try {
      await _synchronize(pending);
      return PublishSubmissionResult.synchronized;
    } on FirebaseException catch (error) {
      if (isOfflineFirebaseError(error)) return PublishSubmissionResult.pending;
      await _discard(pending);
      throw PublishingFailure(_friendlyFirebaseError(error));
    } on TimeoutException {
      return PublishSubmissionResult.pending;
    } on SocketException {
      return PublishSubmissionResult.pending;
    } on PublishingFailure {
      await _discard(pending);
      rethrow;
    } catch (_) {
      await _discard(pending);
      throw const PublishingFailure(
        'No se pudo registrar la publicación. Inténtalo nuevamente.',
      );
    }
  }

  Future<int> synchronizePending(String authorId) async {
    final pending = await _pendingStore.readAll(authorId: authorId);
    var synchronized = 0;
    for (final operation in pending) {
      try {
        await _synchronize(operation);
        synchronized++;
      } on FirebaseException catch (error) {
        // Un rechazo de reglas no se arregla reintentando; la pendiente se
        // descarta para que no vuelva en cada arranque.
        if (!isOfflineFirebaseError(error)) await _discard(operation);
      } on PublishingFailure {
        await _discard(operation);
      } catch (_) {
        // Sin red o con corte: se conserva para el siguiente intento.
      }
    }
    return synchronized;
  }

  Future<int> pendingCount(String authorId) async {
    return (await _pendingStore.readAll(authorId: authorId)).length;
  }

  /// Idempotente: cada foto se sube solo si no está en Storage y el
  /// documento solo se escribe si no existe. El id fijo de la pendiente es
  /// lo que hace que repetir la pasada no duplique nada.
  Future<void> _synchronize(PendingPublication pending) async {
    final imageUrls = <String>[];
    for (final photo in pending.photos) {
      final reference = _imageReference(pending, photo);
      if (!await _exists(reference)) {
        final file = File(photo.localPath);
        if (!await file.exists()) {
          throw const PublishingFailure(
            'Las fotografías de la publicación pendiente ya no están en el dispositivo.',
          );
        }
        final upload = reference.putFile(
          file,
          SettableMetadata(contentType: photo.contentType),
        );
        try {
          await upload.timeout(_uploadTimeout);
        } on TimeoutException {
          await upload.cancel();
          rethrow;
        }
      }
      imageUrls.add(
        await reference.getDownloadURL().timeout(_storageLookupTimeout),
      );
    }

    final document = _firestore
        .collection('publicaciones')
        .doc(pending.publicationId);
    // Si la escritura anterior se encoló y expiró el corte, aquí aparece
    // desde la caché y la pendiente se descarta sin escribir de nuevo.
    final snapshot = await document.get().timeout(firestoreCommitTimeout);
    if (snapshot.exists) {
      await _pendingStore.remove(pending);
      return;
    }
    await document
        .set({
          'authorId': pending.authorId,
          'title': pending.title,
          'category': pending.category,
          'condition': pending.condition,
          'description': pending.description,
          'details': pending.details.map((detail) => detail.toMap()).toList(),
          'district': pending.district,
          'mode': pending.mode.wireValue,
          'deliveryType': pending.deliveryType?.wireValue,
          'status': PublicationStatus.published.wireValue,
          'images': imageUrls,
          'publishedAt': FieldValue.serverTimestamp(),
          'statusDates': {
            PublicationStatus.published.wireValue: FieldValue.serverTimestamp(),
          },
        })
        .timeout(firestoreCommitTimeout);
    await _pendingStore.remove(pending);
  }

  /// Anula una publicación propia (HU03-18). La regla de Firestore solo
  /// admite el paso publicada -> anulada y únicamente sobre `status`, por lo
  /// que no se registra fecha del hito: una publicación anulada sale de la
  /// consulta pública y no tiene recorrido.
  Future<void> withdraw(String publicationId) async {
    try {
      await _firestore.collection('publicaciones').doc(publicationId).update({
        'status': PublicationStatus.cancelled.wireValue,
      });
    } on FirebaseException catch (error) {
      throw PublishingFailure(
        error.code == 'permission-denied'
            ? 'La publicación ya no se puede anular porque tiene un compromiso asociado.'
            : _friendlyFirebaseError(error),
      );
    }
  }

  Reference _imageReference(PendingPublication pending, PendingPhoto photo) {
    return _storage.ref(
      'publicaciones/${pending.authorId}/${pending.publicationId}/foto_${photo.index}.${photo.extension}',
    );
  }

  Future<bool> _exists(Reference reference) async {
    try {
      await reference.getMetadata().timeout(_storageLookupTimeout);
      return true;
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') return false;
      rethrow;
    }
  }

  /// Fallo definitivo: se quita la pendiente del disco y se limpian las fotos
  /// que alcanzaron a subir, para no dejar archivos sin publicación.
  Future<void> _discard(PendingPublication pending) async {
    await _pendingStore.remove(pending);
    for (final photo in pending.photos) {
      try {
        await _imageReference(pending, photo).delete();
      } catch (_) {
        // Limpieza de mejor esfuerzo; nunca oculta el error original.
      }
    }
  }
}

class PublishingFailure implements Exception {
  const PublishingFailure(this.message);

  final String message;
}

String _friendlyFirebaseError(FirebaseException error) {
  if (isPermissionFirebaseError(error)) {
    return 'Tu sesión no permite publicar. Vuelve a iniciar sesión.';
  }
  return 'No se pudo registrar la publicación. Tus datos se conservaron para que puedas reintentar.';
}
