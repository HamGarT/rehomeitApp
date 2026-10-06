import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/domain/publication.dart';
import '../domain/publication_report.dart';

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  return ModerationRepository(FirebaseFirestore.instance);
});

class ModerationRepository {
  ModerationRepository(this._firestore);

  final FirebaseFirestore _firestore;

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
}

class ReportFailure implements Exception {
  const ReportFailure(this.message);

  final String message;
}

String _friendlyReportError(FirebaseException error) {
  if (error.code == 'unavailable' || error.code == 'network-request-failed') {
    return 'No se pudo enviar el reporte. Revisa tu conexión.';
  }
  if (error.code == 'permission-denied') {
    // La regla nega el id ya escrito, que es el motivo más probable: la misma
    // persona ya reportó esa publicación.
    return 'No se pudo enviar el reporte. Es posible que ya lo hayas enviado para esta publicación.';
  }
  if (error.code == 'unauthenticated' || error.code == 'unauthorized') {
    return 'Tu sesión no permite reportar. Vuelve a iniciar sesión.';
  }
  return 'No se pudo enviar el reporte. Inténtalo nuevamente.';
}
