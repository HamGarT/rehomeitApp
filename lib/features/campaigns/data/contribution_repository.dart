import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_errors.dart';
import '../../../core/firebase/firestore_commit.dart';
import '../../../shared/data/notification_payload.dart';
import '../domain/campaign.dart';
import '../domain/contribution.dart';

final contributionRepositoryProvider = Provider<ContributionRepository>((ref) {
  return ContributionRepository(FirebaseFirestore.instance);
});

class ContributionRepository {
  ContributionRepository(this._firestore);

  static const _contributionsCollection = 'aportes';
  static const _profileLookupTimeout = Duration(seconds: 4);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _contributions =>
      _firestore.collection(_contributionsCollection);

  CollectionReference<Map<String, dynamic>> get _campaigns =>
      _firestore.collection('campaigns');

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notificaciones');

  /// Aportes de una persona. Filtra por un solo campo y sin `orderBy`, igual
  /// que `watchOwnCampaigns`, para no depender de un índice compuesto. El
  /// orden por fecha se resuelve en el cliente.
  Stream<List<Contribution>> watchByContributor(String contributorId) {
    return _contributions
        .where('contributorId', isEqualTo: contributorId)
        .snapshots(includeMetadataChanges: true)
        .map(_toContributions);
  }

  /// Aportes pendientes de una organización. Dos igualdades sin `orderBy` se
  /// resuelven con los índices de un solo campo, así que no hace falta un
  /// índice compuesto.
  Stream<List<Contribution>> watchPendingByOrganization(String organizationId) {
    return _contributions
        .where('organizationId', isEqualTo: organizationId)
        .where('status', isEqualTo: ContributionStatus.pending.wireValue)
        .snapshots(includeMetadataChanges: true)
        .map(_toContributions);
  }

  List<Contribution> _toContributions(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map(
          (doc) => Contribution.fromMap(
            doc.id,
            doc.data(),
            hasPendingWrites: doc.metadata.hasPendingWrites,
          ),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> register({
    required Campaign campaign,
    required CampaignNeed need,
    required int quantity,
    required String contributorId,
  }) async {
    if (quantity <= 0) {
      throw const ContributionFailure('Indica una cantidad mayor que cero.');
    }
    final document = _contributions.doc();
    final contributorName = await _contributorName(contributorId);
    final batch = _firestore.batch();
    batch.set(document, {
      'campaignId': campaign.id,
      'campaignTitle': campaign.title,
      'organizationId': campaign.organizationId,
      'needId': need.id,
      'needName': need.name,
      'quantity': quantity,
      'contributorId': contributorId,
      'contributorName': contributorName,
      'status': ContributionStatus.pending.wireValue,
      'createdAt': FieldValue.serverTimestamp(),
      'confirmedAt': null,
      'confirmedBy': null,
      'rejectedAt': null,
      'rejectedBy': null,
      'rejectionReason': null,
    });
    try {
      await commitOfflineTolerant(batch);
    } on FirebaseException catch (error) {
      throw ContributionFailure(_friendlyError(error));
    }
  }

  Future<void> confirm({
    required Contribution contribution,
    required String organizationId,
  }) async {
    final batch = _firestore.batch();
    batch.update(_contributions.doc(contribution.id), {
      'status': ContributionStatus.confirmed.wireValue,
      'confirmedAt': FieldValue.serverTimestamp(),
      'confirmedBy': organizationId,
    });
    batch.update(_campaigns.doc(contribution.campaignId), {
      'contributions.${contribution.needId}': FieldValue.increment(
        contribution.quantity,
      ),
      'lastContributionId': contribution.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _notifications.doc('aporte_confirmado_${contribution.id}'),
      notificationPayload(
        recipientId: contribution.contributorId,
        type: 'aporte_confirmado',
        message:
            'Confirmaron tu aporte de ${contribution.quantity} ${contribution.needName} a ${contribution.campaignTitle}.',
        campaignId: contribution.campaignId,
        contributionId: contribution.id,
        actorId: organizationId,
      ),
    );
    try {
      await commitOfflineTolerant(batch);
    } on FirebaseException catch (error) {
      throw ContributionFailure(_friendlyError(error));
    }
  }

  Future<void> reject({
    required Contribution contribution,
    required String organizationId,
    required String reason,
  }) async {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      throw const ContributionFailure('Indica el motivo del rechazo.');
    }
    final batch = _firestore.batch();
    batch.update(_contributions.doc(contribution.id), {
      'status': ContributionStatus.rejected.wireValue,
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectedBy': organizationId,
      'rejectionReason': trimmed,
    });
    batch.set(
      _notifications.doc('aporte_rechazado_${contribution.id}'),
      notificationPayload(
        recipientId: contribution.contributorId,
        type: 'aporte_rechazado',
        message:
            'Rechazaron tu aporte a ${contribution.campaignTitle}: $trimmed',
        campaignId: contribution.campaignId,
        contributionId: contribution.id,
        actorId: organizationId,
      ),
    );
    try {
      await commitOfflineTolerant(batch);
    } on FirebaseException catch (error) {
      throw ContributionFailure(_friendlyError(error));
    }
  }

  Future<String> _contributorName(String contributorId) async {
    try {
      final snapshot = await _firestore
          .collection('perfiles')
          .doc(contributorId)
          .get()
          .timeout(_profileLookupTimeout);
      final name = (snapshot.data()?['nombreCorto'] as String?)?.trim();
      if (name != null && name.isNotEmpty) return name;
    } on TimeoutException {
      return 'Usuario';
    } on FirebaseException {
      return 'Usuario';
    }
    return 'Usuario';
  }
}

class ContributionFailure implements Exception {
  const ContributionFailure(this.message);

  final String message;
}

String _friendlyError(FirebaseException error) {
  if (isOfflineFirebaseError(error)) {
    return 'Sin conexión. Tu aporte se conservará para sincronizarse.';
  }
  if (isPermissionFirebaseError(error)) {
    return 'La operación no está permitida para el estado actual de la campaña.';
  }
  return 'No se pudo completar la operación (${error.code}).';
}
