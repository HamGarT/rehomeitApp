import 'package:cloud_firestore/cloud_firestore.dart';

/// Motivo con el que se reporta una publicación (HU19, criterio 3).
///
/// Los valores de [wireValue] son los que valida `validInitialReport` en
/// `firestore.rules`: agregar uno aquí sin abrir la regla deja el motivo
/// rechazado por el servidor.
enum ReportReason {
  inappropriateContent,
  illegalItem,
  misleading,
  moneyRequest,
  other,
}

/// Estado del reporte. "Pendiente" es el único que escribe la aplicación; los
/// otros dos los resuelve el equipo administrador (HU19, criterios 10 y 11).
enum ReportStatus { pending, dismissed, withdrawn }

/// Reporte de una publicación, con el estado en que lo dejó quien lo escribió.
///
/// No tiene `fromMap` a propósito: hoy la aplicación solo escribe reportes. La
/// lectura del listado y la resolución llegan con la consola de moderación
/// (HU19, criterios 8 a 14) y serán el reverso de este mismo esquema.
class PublicationReport {
  const PublicationReport({
    required this.id,
    required this.publicationId,
    required this.reporterId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.comment,
    this.resolvedAt,
    this.resolvedBy,
  });

  /// Límite del comentario opcional. Lo comparten la hoja de reporte, que
  /// corta la escritura, y `validInitialReport`, que rechaza el documento
  /// entero: un texto más largo no se guarda truncado a medias.
  static const int maxCommentLength = 500;

  final String id;
  final String publicationId;
  final String reporterId;
  final ReportReason reason;
  final ReportStatus status;
  final DateTime createdAt;
  final String? comment;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  /// Id del documento: la persona que reporta y la publicación, en ese orden.
  ///
  /// Es determinista a propósito. El mismo par siempre cae en el mismo
  /// documento, así el segundo reporte de la misma publicación llega a Firestore
  /// como `update` sobre algo ya escrito y la regla lo nega sin que la
  /// aplicación tenga que consultar si ya se reportó (HU19, criterio 4).
  static String documentIdFor({
    required String reporterId,
    required String publicationId,
  }) {
    return '${reporterId}_$publicationId';
  }

  /// Los campos de resolución se escriben ya en `null`: la regla los exige
  /// presentes y vacíos en la creación, igual que `validInitialProposal` hace
  /// con `respondedAt`.
  Map<String, Object?> toMap() => {
    'publicationId': publicationId,
    'reporterId': reporterId,
    'reason': reason.wireValue,
    'comment': comment,
    'status': status.wireValue,
    'createdAt': Timestamp.fromDate(createdAt),
    'resolvedAt': resolvedAt == null ? null : Timestamp.fromDate(resolvedAt!),
    'resolvedBy': resolvedBy,
  };
}

extension ReportReasonWire on ReportReason {
  String get wireValue => switch (this) {
    ReportReason.inappropriateContent => 'contenido_inapropiado',
    ReportReason.illegalItem => 'bien_prohibido',
    ReportReason.misleading => 'publicacion_enganosa',
    ReportReason.moneyRequest => 'solicitud_de_dinero',
    ReportReason.other => 'otro',
  };

  String get label => switch (this) {
    ReportReason.inappropriateContent => 'Contenido inapropiado',
    ReportReason.illegalItem => 'Bien prohibido o ilegal',
    ReportReason.misleading => 'Publicación engañosa',
    ReportReason.moneyRequest => 'Solicitud de dinero',
    ReportReason.other => 'Otro motivo',
  };

  static ReportReason fromValue(String? value) => switch (value) {
    'contenido_inapropiado' => ReportReason.inappropriateContent,
    'bien_prohibido' => ReportReason.illegalItem,
    'publicacion_enganosa' => ReportReason.misleading,
    'solicitud_de_dinero' => ReportReason.moneyRequest,
    'otro' => ReportReason.other,
    _ => throw FormatException('Motivo de reporte inválido: $value'),
  };
}

extension ReportStatusWire on ReportStatus {
  String get wireValue => switch (this) {
    ReportStatus.pending => 'pendiente',
    ReportStatus.dismissed => 'desestimado',
    ReportStatus.withdrawn => 'retirada',
  };

  String get label => switch (this) {
    ReportStatus.pending => 'Pendiente',
    ReportStatus.dismissed => 'Desestimado',
    ReportStatus.withdrawn => 'Retirada',
  };

  static ReportStatus fromValue(String? value) => switch (value) {
    'pendiente' => ReportStatus.pending,
    'desestimado' => ReportStatus.dismissed,
    'retirada' => ReportStatus.withdrawn,
    _ => throw FormatException('Estado de reporte inválido: $value'),
  };
}
