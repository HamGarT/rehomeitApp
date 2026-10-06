import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehomeitapp/features/moderation/domain/publication_report.dart';

PublicationReport _report({
  ReportReason reason = ReportReason.inappropriateContent,
  ReportStatus status = ReportStatus.pending,
  String? comment,
}) {
  return PublicationReport(
    id: PublicationReport.documentIdFor(
      reporterId: 'reporter',
      publicationId: 'publication',
    ),
    publicationId: 'publication',
    reporterId: 'reporter',
    reason: reason,
    status: status,
    createdAt: DateTime.utc(2026, 9, 23, 15),
    comment: comment,
  );
}

void main() {
  test('el id del reporte es la persona y la publicación, en ese orden', () {
    // El orden importa: la regla compara el id del documento con
    // `reporterId + '_' + publicationId`, y cualquier cambio rompe el
    // determinismo que impide el segundo reporte.
    expect(
      PublicationReport.documentIdFor(
        reporterId: 'reporter',
        publicationId: 'publication',
      ),
      'reporter_publication',
    );
  });

  test('el mismo par cae siempre en el mismo documento', () {
    String idOf() => PublicationReport.documentIdFor(
      reporterId: 'reporter',
      publicationId: 'publication',
    );

    expect(idOf(), idOf());
    expect(
      idOf(),
      isNot(
        PublicationReport.documentIdFor(
          reporterId: 'otra',
          publicationId: 'publication',
        ),
      ),
    );
  });

  test('el reporte nace pendiente y con los campos de resolución vacíos', () {
    // Los tres campos de resolución se escriben en `null` porque la regla los
    // exige presentes en la creación; si faltaran, el documento se rechazaría.
    final map = _report().toMap();

    expect(map['status'], 'pendiente');
    expect(map['createdAt'], isA<Timestamp>());
    expect(map['resolvedAt'], isNull);
    expect(map['resolvedBy'], isNull);
    expect(
      map.keys,
      containsAll([
        'publicationId',
        'reporterId',
        'reason',
        'comment',
        'status',
        'createdAt',
        'resolvedAt',
        'resolvedBy',
      ]),
    );
  });

  test('los cinco motivos previstos conservan su valor de Firestore', () {
    expect(ReportReason.values.map((reason) => reason.wireValue), [
      'contenido_inapropiado',
      'bien_prohibido',
      'publicacion_enganosa',
      'solicitud_de_dinero',
      'otro',
    ]);
    // Todos tienen que poder volver de su valor de Firestore: son los que
    // valida la regla y los que escribirá la consola de moderación.
    for (final reason in ReportReason.values) {
      expect(ReportReasonWire.fromValue(reason.wireValue), reason);
      expect(reason.label, isNotEmpty);
    }
  });

  test('el comentario se guarda tal cual, y su ausencia es `null`', () {
    expect(
      _report(comment: 'Foto que no corresponde').toMap()['comment'],
      'Foto que no corresponde',
    );
    expect(_report().toMap()['comment'], isNull);
  });

  test('los estados del reporte vuelven de su valor de Firestore', () {
    expect(ReportStatusWire.fromValue('pendiente'), ReportStatus.pending);
    expect(ReportStatusWire.fromValue('desestimado'), ReportStatus.dismissed);
    expect(ReportStatusWire.fromValue('retirada'), ReportStatus.withdrawn);
    expect(ReportStatus.dismissed.wireValue, 'desestimado');
  });

  test(
    'un motivo o estado desconocido se rechaza en vez de inventarse uno',
    () {
      expect(
        () => ReportReasonWire.fromValue('inventado'),
        throwsFormatException,
      );
      expect(() => ReportStatusWire.fromValue(null), throwsFormatException);
    },
  );

  test('el límite del comentario es el que comparte la hoja y la regla', () {
    expect(PublicationReport.maxCommentLength, 500);
  });
}
