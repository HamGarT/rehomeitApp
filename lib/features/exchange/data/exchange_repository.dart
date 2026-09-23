import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/domain/publication.dart';
import '../domain/exchange_proposal.dart';

final exchangeRepositoryProvider = Provider<ExchangeRepository>((ref) {
  return ExchangeRepository(FirebaseFirestore.instance);
});

class ExchangeRepository {
  ExchangeRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<List<Publication>> watchEligiblePublications(String authorId) {
    return _firestore
        .collection('publicaciones')
        .where('authorId', isEqualTo: authorId)
        .where('mode', isEqualTo: PublicationMode.exchange.wireValue)
        .where('status', isEqualTo: PublicationStatus.published.wireValue)
        .orderBy('publishedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Publication.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  Stream<List<ExchangeProposal>> watchUserProposals(String userId) {
    return _firestore
        .collection('propuestasIntercambio')
        .where('participantIds', arrayContains: userId)
        .orderBy('proposedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ExchangeProposal.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  Future<void> propose({
    required String requestedPublicationId,
    required String offeredPublicationId,
    required String proposerId,
  }) async {
    if (requestedPublicationId == offeredPublicationId) {
      throw const ExchangeFailure('Selecciona otra publicación para ofrecer.');
    }

    final requestedRef = _firestore
        .collection('publicaciones')
        .doc(requestedPublicationId);
    final offeredRef = _firestore
        .collection('publicaciones')
        .doc(offeredPublicationId);
    final proposalRef = _firestore.collection('propuestasIntercambio').doc();
    final notificationRef = _firestore.collection('notificaciones').doc();

    try {
      await _firestore.runTransaction((transaction) async {
        final requestedSnapshot = await transaction.get(requestedRef);
        final offeredSnapshot = await transaction.get(offeredRef);
        if (!requestedSnapshot.exists || !offeredSnapshot.exists) {
          throw const ExchangeFailure(
            'Una de las publicaciones ya no está disponible.',
          );
        }

        final requested = Publication.fromMap(
          requestedSnapshot.id,
          requestedSnapshot.data()!,
        );
        final offered = Publication.fromMap(
          offeredSnapshot.id,
          offeredSnapshot.data()!,
        );
        if (requested.authorId == proposerId) {
          throw const ExchangeFailure(
            'No puedes proponer un intercambio sobre tu propia publicación.',
          );
        }
        if (offered.authorId != proposerId) {
          throw const ExchangeFailure(
            'Solo puedes ofrecer una publicación propia.',
          );
        }
        _requireAvailableExchange(requested);
        _requireAvailableExchange(offered);

        final now = DateTime.now().toUtc();
        final proposal = ExchangeProposal(
          id: proposalRef.id,
          requestedPublicationId: requested.id,
          requestedPublicationTitle: requested.title,
          requestedOwnerId: requested.authorId,
          offeredPublicationId: offered.id,
          offeredPublicationTitle: offered.title,
          offeredOwnerId: offered.authorId,
          requestedImageUrl: requested.images.isEmpty
              ? null
              : requested.images.first,
          offeredImageUrl: offered.images.isEmpty ? null : offered.images.first,
          status: ExchangeProposalStatus.pending,
          proposedAt: now,
        );
        transaction.set(proposalRef, {
          ...proposal.toMap(),
          'proposedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(
          notificationRef,
          _notification(
            recipientId: requested.authorId,
            type: 'propuesta_intercambio',
            message: 'Recibiste una propuesta por ${requested.title}.',
            proposalId: proposalRef.id,
            publicationId: requested.id,
          ),
        );
      });
    } on ExchangeFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw ExchangeFailure(_firebaseMessage(error));
    }
  }

  Future<void> respond({
    required String proposalId,
    required String ownerId,
    required bool accept,
  }) async {
    final proposalRef = _firestore
        .collection('propuestasIntercambio')
        .doc(proposalId);

    try {
      await _firestore.runTransaction((transaction) async {
        final proposalSnapshot = await transaction.get(proposalRef);
        if (!proposalSnapshot.exists) {
          throw const ExchangeFailure('La propuesta ya no existe.');
        }
        final proposal = ExchangeProposal.fromMap(
          proposalSnapshot.id,
          proposalSnapshot.data()!,
        );
        if (proposal.requestedOwnerId != ownerId) {
          throw const ExchangeFailure(
            'Solo el propietario puede responder esta propuesta.',
          );
        }
        if (proposal.status != ExchangeProposalStatus.pending) {
          throw const ExchangeFailure('La propuesta ya fue respondida.');
        }

        if (!accept) {
          transaction.update(proposalRef, {
            'status': ExchangeProposalStatus.rejected.wireValue,
            'respondedAt': FieldValue.serverTimestamp(),
          });
          transaction.set(
            _firestore.collection('notificaciones').doc(),
            _notification(
              recipientId: proposal.offeredOwnerId,
              type: 'propuesta_rechazada',
              message:
                  'Tu propuesta por ${proposal.requestedPublicationTitle} fue rechazada.',
              proposalId: proposal.id,
              publicationId: proposal.requestedPublicationId,
            ),
          );
          return;
        }

        final requestedRef = _firestore
            .collection('publicaciones')
            .doc(proposal.requestedPublicationId);
        final offeredRef = _firestore
            .collection('publicaciones')
            .doc(proposal.offeredPublicationId);
        final requestedSnapshot = await transaction.get(requestedRef);
        final offeredSnapshot = await transaction.get(offeredRef);
        if (!requestedSnapshot.exists || !offeredSnapshot.exists) {
          throw const ExchangeFailure(
            'Una de las publicaciones ya no está disponible.',
          );
        }
        final requested = Publication.fromMap(
          requestedSnapshot.id,
          requestedSnapshot.data()!,
        );
        final offered = Publication.fromMap(
          offeredSnapshot.id,
          offeredSnapshot.data()!,
        );
        _requireAvailableExchange(requested);
        _requireAvailableExchange(offered);

        transaction.update(requestedRef, {
          'status': PublicationStatus.committed.wireValue,
          'exchangeProposalId': proposal.id,
          'counterpartPublicationId': offered.id,
          'counterpartUserId': offered.authorId,
          'committedAt': FieldValue.serverTimestamp(),
          'statusDates.${PublicationStatus.committed.wireValue}':
              FieldValue.serverTimestamp(),
        });
        transaction.update(offeredRef, {
          'status': PublicationStatus.committed.wireValue,
          'exchangeProposalId': proposal.id,
          'counterpartPublicationId': requested.id,
          'counterpartUserId': requested.authorId,
          'committedAt': FieldValue.serverTimestamp(),
          'statusDates.${PublicationStatus.committed.wireValue}':
              FieldValue.serverTimestamp(),
        });
        transaction.update(proposalRef, {
          'status': ExchangeProposalStatus.accepted.wireValue,
          'respondedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(
          _firestore.collection('notificaciones').doc(),
          _notification(
            recipientId: proposal.offeredOwnerId,
            type: 'propuesta_aceptada',
            message:
                'Tu propuesta por ${proposal.requestedPublicationTitle} fue aceptada.',
            proposalId: proposal.id,
            publicationId: proposal.requestedPublicationId,
          ),
        );
      });
    } on ExchangeFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw ExchangeFailure(_firebaseMessage(error));
    }
  }

  Future<void> confirmReceipt({
    required String proposalId,
    required String userId,
  }) async {
    final proposalRef = _firestore
        .collection('propuestasIntercambio')
        .doc(proposalId);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(proposalRef);
        if (!snapshot.exists) {
          throw const ExchangeFailure('El intercambio ya no existe.');
        }
        final proposal = ExchangeProposal.fromMap(
          snapshot.id,
          snapshot.data()!,
        );
        if (proposal.status != ExchangeProposalStatus.accepted) {
          throw const ExchangeFailure(
            'Solo se puede confirmar un intercambio aceptado.',
          );
        }
        if (!proposal.participantIds.contains(userId)) {
          throw const ExchangeFailure('No participas en este intercambio.');
        }
        if (proposal.hasConfirmed(userId)) {
          throw const ExchangeFailure('Ya confirmaste la recepción.');
        }

        final isRequestedOwner = userId == proposal.requestedOwnerId;
        final otherAlreadyConfirmed = isRequestedOwner
            ? proposal.offeredOwnerConfirmedAt != null
            : proposal.requestedOwnerConfirmedAt != null;
        transaction.update(proposalRef, {
          isRequestedOwner
                  ? 'requestedOwnerConfirmedAt'
                  : 'offeredOwnerConfirmedAt':
              FieldValue.serverTimestamp(),
        });

        final publicationStatus = otherAlreadyConfirmed
            ? PublicationStatus.confirmed
            : PublicationStatus.delivered;
        transaction.update(
          _firestore
              .collection('publicaciones')
              .doc(proposal.requestedPublicationId),
          {
            'status': publicationStatus.wireValue,
            'statusDates.${publicationStatus.wireValue}':
                FieldValue.serverTimestamp(),
          },
        );
        transaction.update(
          _firestore
              .collection('publicaciones')
              .doc(proposal.offeredPublicationId),
          {
            'status': publicationStatus.wireValue,
            'statusDates.${publicationStatus.wireValue}':
                FieldValue.serverTimestamp(),
          },
        );
        transaction.set(
          _firestore.collection('notificaciones').doc(),
          _notification(
            recipientId: isRequestedOwner
                ? proposal.offeredOwnerId
                : proposal.requestedOwnerId,
            type: otherAlreadyConfirmed
                ? 'intercambio_confirmado'
                : 'confirmacion_intercambio_pendiente',
            message: otherAlreadyConfirmed
                ? 'El intercambio quedó confirmado por ambas partes.'
                : 'La otra parte confirmó la recepción. Falta tu confirmación.',
            proposalId: proposal.id,
            publicationId: proposal.requestedPublicationId,
          ),
        );
      });
    } on ExchangeFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw ExchangeFailure(_firebaseMessage(error));
    }
  }

  void _requireAvailableExchange(Publication publication) {
    if (publication.mode != PublicationMode.exchange ||
        publication.status != PublicationStatus.published) {
      throw const ExchangeFailure(
        'Una de las publicaciones ya no está disponible para intercambio.',
      );
    }
  }
}

Map<String, Object?> _notification({
  required String recipientId,
  required String type,
  required String message,
  required String proposalId,
  required String publicationId,
}) {
  return {
    'recipientId': recipientId,
    'type': type,
    'message': message,
    'proposalId': proposalId,
    'publicationId': publicationId,
    'createdAt': FieldValue.serverTimestamp(),
    'read': false,
  };
}

class ExchangeFailure implements Exception {
  const ExchangeFailure(this.message);

  final String message;
}

String _firebaseMessage(FirebaseException error) {
  if (error.code == 'unavailable' || error.code == 'network-request-failed') {
    return 'No se pudo completar la operación. Revisa tu conexión.';
  }
  if (error.code == 'failed-precondition' &&
      (error.message?.contains('index') ?? false)) {
    return 'Falta configurar un índice de Firestore para esta consulta.';
  }
  return 'No se pudo completar la operación. Inténtalo nuevamente.';
}
