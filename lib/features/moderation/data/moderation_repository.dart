import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_errors.dart';
import '../../../shared/data/notification_payload.dart';
import '../../../shared/domain/publication.dart';
import '../../exchange/domain/exchange_proposal.dart';
import '../domain/publication_report.dart';

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  return ModerationRepository(FirebaseFirestore.instance);
});

class ModerationRepository {
  ModerationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  static const _adminRole = 'administrador';

  /// El rol vive en `usuarios` y lo asigna el backend (D06). La consola solo
  /// se muestra con `true`; la protección real está en las reglas.
  Stream<bool> watchIsAdmin(String userId) {
    return _firestore
        .collection('usuarios')
        .doc(userId)
        .snapshots()
        .map((document) => document.data()?['rol'] == _adminRole);
  }

  /// Reportes pendientes del más antiguo al más nuevo (HU19-8). Exige el
  /// índice `status ASC + createdAt ASC` de `firestore.indexes.json`.
  Stream<List<PublicationReport>> watchPendingReports() {
    return _firestore
        .collection('reportes')
        .where('status', isEqualTo: ReportStatus.pending.wireValue)
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PublicationReport.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  /// Registra el reporte de una publicación ajena (HU19, criterios 5 y 6).
  ///
  /// El reporte nace "pendiente" y sin resolución; el equipo administrador lo
  /// mueve después. La publicación no se toca: sigue visible mientras el
  /// reporte no se resuelva (criterio 7).
  Future<void> report({
    required Publication publication,
    required String reporterId,
    required ReportReason reason,
    String? comment,
  }) async {
    if (publication.authorId == reporterId) {
      throw const ReportFailure('No puedes reportar tu propia publicación.');
    }
    final text = comment?.trim();
    if (text != null && text.length > PublicationReport.maxCommentLength) {
      throw const ReportFailure(
        'El comentario supera los ${PublicationReport.maxCommentLength} caracteres.',
      );
    }

    final report = PublicationReport(
      id: PublicationReport.documentIdFor(
        reporterId: reporterId,
        publicationId: publication.id,
      ),
      publicationId: publication.id,
      reporterId: reporterId,
      reason: reason,
      status: ReportStatus.pending,
      createdAt: DateTime.now().toUtc(),
      comment: text == null || text.isEmpty ? null : text,
    );

    try {
      await _firestore.collection('reportes').doc(report.id).set({
        ...report.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw ReportFailure(_friendlyReportError(error));
    }
  }

  /// Desestima el reporte y avisa a quien reportó (HU19-11 y 14). La
  /// publicación no se toca.
  Future<void> dismiss({
    required PublicationReport report,
    required Publication publication,
    required String adminId,
  }) async {
    final batch = _firestore.batch();
    _resolveReport(
      batch,
      report: report,
      status: ReportStatus.dismissed,
      adminId: adminId,
      publicationTitle: publication.title,
    );
    await _commit(batch);
  }

  /// Retira la publicación y resuelve el reporte en un solo lote (HU19-10 a
  /// 16): la publicación pasa a retirada, el compromiso o la propuesta aceptada
  /// se cancela, la contraparte de un intercambio vuelve a estar disponible y
  /// se avisa al autor, a quien reportó y a la otra parte.
  ///
  /// Los demás reportes y propuestas pendientes se cierran después, uno por
  /// lote: las reglas admiten como máximo 20 lecturas por lote y cada
  /// escritura de moderación gasta varias, así que el lote atómico se limita a
  /// lo que no puede quedar a medias (D16).
  Future<void> removePublication({
    required PublicationReport report,
    required Publication publication,
    required String adminId,
  }) async {
    if (!publication.isRemovableByModeration) {
      throw const ModerationFailure(
        'Esta publicación ya no se puede retirar: el bien cambió de manos.',
      );
    }

    final batch = _firestore.batch();
    batch.update(_publicationRef(publication.id), {
      'status': PublicationStatus.removed.wireValue,
      'statusDates.${PublicationStatus.removed.wireValue}':
          FieldValue.serverTimestamp(),
    });
    if (publication.status == PublicationStatus.committed) {
      if (publication.isDonation) {
        _cancelDonationCommitment(batch, publication, adminId);
      } else {
        _cancelAcceptedExchange(batch, publication, adminId);
      }
    }
    _resolveReport(
      batch,
      report: report,
      status: ReportStatus.withdrawn,
      adminId: adminId,
      publicationTitle: publication.title,
    );
    _notify(
      batch,
      recipientId: publication.authorId,
      adminId: adminId,
      type: 'publicacion_retirada',
      message:
          'Tu publicación «${publication.title}» fue retirada por el equipo. '
          'Motivo: ${report.reason.label}.',
      publicationId: publication.id,
    );
    await _commit(batch);
    await _closePendingAfterRemoval(publication, adminId);
  }

  /// Cierra un reporte pendiente cuya publicación ya está retirada (porque
  /// otro reporte la retiró antes o porque la limpieza se interrumpió) y
  /// reintenta esa limpieza.
  Future<void> resolveAlreadyRemoved({
    required PublicationReport report,
    required Publication publication,
    required String adminId,
  }) async {
    if (publication.status != PublicationStatus.removed) {
      throw const ModerationFailure('La publicación no está retirada.');
    }
    final batch = _firestore.batch();
    _resolveReport(
      batch,
      report: report,
      status: ReportStatus.withdrawn,
      adminId: adminId,
      publicationTitle: publication.title,
    );
    await _commit(batch);
    await _closePendingAfterRemoval(publication, adminId);
  }

  void _cancelDonationCommitment(
    WriteBatch batch,
    Publication publication,
    String adminId,
  ) {
    final volunteerId = publication.volunteerId;
    if (volunteerId == null) return;
    _notify(
      batch,
      recipientId: volunteerId,
      adminId: adminId,
      type: 'compromiso_cancelado',
      message:
          'El recojo de «${publication.title}» quedó cancelado porque la '
          'publicación fue retirada.',
      publicationId: publication.id,
    );
  }

  void _cancelAcceptedExchange(
    WriteBatch batch,
    Publication publication,
    String adminId,
  ) {
    final proposalId = publication.exchangeProposalId;
    final counterpartId = publication.counterpartPublicationId;
    final counterpartUserId = publication.counterpartUserId;
    if (proposalId == null || counterpartId == null) return;
    _cancelProposal(batch, proposalId);
    batch.update(_publicationRef(counterpartId), {
      'status': PublicationStatus.published.wireValue,
      'exchangeProposalId': FieldValue.delete(),
      'counterpartPublicationId': FieldValue.delete(),
      'counterpartUserId': FieldValue.delete(),
      'committedAt': FieldValue.delete(),
    });
    if (counterpartUserId == null) return;
    _notify(
      batch,
      recipientId: counterpartUserId,
      adminId: adminId,
      type: 'compromiso_cancelado',
      message:
          'El intercambio por «${publication.title}» quedó cancelado porque '
          'la publicación fue retirada. Tu publicación vuelve a estar '
          'disponible.',
      publicationId: publication.id,
      proposalId: proposalId,
    );
  }

  /// Reportes y propuestas pendientes que quedaron sobre una publicación ya
  /// retirada. Un lote por documento; si alguno falla, el resto sigue y el
  /// error se informa al final.
  Future<void> _closePendingAfterRemoval(
    Publication publication,
    String adminId,
  ) async {
    var failures = 0;
    final reports = await _pendingReportsOf(publication.id);
    for (final report in reports) {
      final batch = _firestore.batch();
      _resolveReport(
        batch,
        report: report,
        status: ReportStatus.withdrawn,
        adminId: adminId,
        publicationTitle: publication.title,
      );
      if (!await _tryCommit(batch)) failures++;
    }

    final proposals = await _pendingProposalsOf(publication.id);
    for (final proposal in proposals) {
      final batch = _firestore.batch();
      _cancelProposal(batch, proposal.id);
      final retiredIsRequested =
          proposal.requestedPublicationId == publication.id;
      _notify(
        batch,
        recipientId: retiredIsRequested
            ? proposal.offeredOwnerId
            : proposal.requestedOwnerId,
        adminId: adminId,
        type: 'compromiso_cancelado',
        message: retiredIsRequested
            ? 'Tu propuesta por «${proposal.requestedPublicationTitle}» quedó '
                  'cancelada porque la publicación fue retirada.'
            : 'La propuesta que recibiste por «${proposal.requestedPublicationTitle}» '
                  'quedó cancelada porque la publicación ofrecida fue retirada.',
        publicationId: publication.id,
        proposalId: proposal.id,
      );
      if (!await _tryCommit(batch)) failures++;
    }

    if (failures > 0) {
      throw const ModerationFailure(
        'La publicación se retiró, pero quedaron reportes o propuestas por '
        'cerrar. Abre de nuevo un reporte de esta publicación para completarlo.',
      );
    }
  }

  Future<List<PublicationReport>> _pendingReportsOf(
    String publicationId,
  ) async {
    final snapshot = await _firestore
        .collection('reportes')
        .where('publicationId', isEqualTo: publicationId)
        .where('status', isEqualTo: ReportStatus.pending.wireValue)
        .get();
    return snapshot.docs
        .map((doc) => PublicationReport.fromMap(doc.id, doc.data()))
        .toList(growable: false);
  }

  Future<List<ExchangeProposal>> _pendingProposalsOf(
    String publicationId,
  ) async {
    final proposals = _firestore.collection('propuestasIntercambio');
    final pending = ExchangeProposalStatus.pending.wireValue;
    final results = await Future.wait([
      proposals
          .where('requestedPublicationId', isEqualTo: publicationId)
          .where('status', isEqualTo: pending)
          .get(),
      proposals
          .where('offeredPublicationId', isEqualTo: publicationId)
          .where('status', isEqualTo: pending)
          .get(),
    ]);
    return [
      for (final snapshot in results)
        for (final doc in snapshot.docs)
          ExchangeProposal.fromMap(doc.id, doc.data()),
    ];
  }

  void _cancelProposal(WriteBatch batch, String proposalId) {
    // `cancelledAt` no está en el modelo: solo lo exige la regla y ninguna
    // pantalla lo lee. Agregarlo a `toMap` rompería la creación, cuyo esquema
    // es cerrado.
    batch.update(
      _firestore.collection('propuestasIntercambio').doc(proposalId),
      {
        'status': ExchangeProposalStatus.cancelled.wireValue,
        'cancelledAt': FieldValue.serverTimestamp(),
      },
    );
  }

  void _resolveReport(
    WriteBatch batch, {
    required PublicationReport report,
    required ReportStatus status,
    required String adminId,
    required String publicationTitle,
  }) {
    batch.update(_firestore.collection('reportes').doc(report.id), {
      'status': status.wireValue,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': adminId,
    });
    _notify(
      batch,
      recipientId: report.reporterId,
      adminId: adminId,
      type: 'reporte_resuelto',
      message: status == ReportStatus.withdrawn
          ? 'Tu reporte sobre «$publicationTitle» fue revisado: la publicación '
                'fue retirada.'
          : 'Tu reporte sobre «$publicationTitle» fue revisado: la publicación '
                'se mantiene disponible.',
      publicationId: report.publicationId,
      reportId: report.id,
    );
  }

  /// Las reglas rechazan avisarse a uno mismo, y un administrador puede ser
  /// a la vez autor, reportante o contraparte.
  void _notify(
    WriteBatch batch, {
    required String recipientId,
    required String adminId,
    required String type,
    required String message,
    required String publicationId,
    String? proposalId,
    String? reportId,
  }) {
    if (recipientId == adminId) return;
    batch.set(
      _firestore.collection('notificaciones').doc(),
      notificationPayload(
        recipientId: recipientId,
        type: type,
        message: message,
        publicationId: publicationId,
        actorId: adminId,
        proposalId: proposalId,
        reportId: reportId,
      ),
    );
  }

  DocumentReference<Map<String, dynamic>> _publicationRef(String id) =>
      _firestore.collection('publicaciones').doc(id);

  /// Sin tolerancia a desconexión: una resolución encolada que el servidor
  /// rechace al sincronizar dejaría al administrador creyendo que resolvió.
  Future<void> _commit(WriteBatch batch) async {
    try {
      await batch.commit();
    } on FirebaseException catch (error) {
      throw ModerationFailure(_friendlyModerationError(error));
    }
  }

  Future<bool> _tryCommit(WriteBatch batch) async {
    try {
      await batch.commit();
      return true;
    } on FirebaseException {
      return false;
    }
  }
}

class ReportFailure implements Exception {
  const ReportFailure(this.message);

  final String message;
}

class ModerationFailure implements Exception {
  const ModerationFailure(this.message);

  final String message;
}

String _friendlyReportError(FirebaseException error) {
  if (isOfflineFirebaseError(error)) {
    return 'No se pudo enviar el reporte. Revisa tu conexión.';
  }
  if (error.code == 'permission-denied') {
    // La regla niega el id ya escrito, que es el motivo más probable: la misma
    // persona ya reportó esa publicación.
    return 'No se pudo enviar el reporte. Es posible que ya lo hayas enviado para esta publicación.';
  }
  if (isPermissionFirebaseError(error)) {
    return 'Tu sesión no permite reportar. Vuelve a iniciar sesión.';
  }
  return 'No se pudo enviar el reporte. Inténtalo nuevamente.';
}

String _friendlyModerationError(FirebaseException error) {
  if (isOfflineFirebaseError(error)) {
    return 'Sin conexión. La moderación necesita red para resolver.';
  }
  if (error.code == 'permission-denied') {
    // O el estado cambió desde que se abrió el reporte, o la cuenta dejó de
    // ser administradora. En ambos casos lo correcto es volver a cargar.
    return 'No se pudo resolver: la publicación o el reporte cambiaron. Actualiza la lista.';
  }
  if (isPermissionFirebaseError(error)) {
    return 'Tu sesión no permite moderar. Vuelve a iniciar sesión.';
  }
  return 'No se pudo resolver el reporte. Inténtalo nuevamente.';
}
