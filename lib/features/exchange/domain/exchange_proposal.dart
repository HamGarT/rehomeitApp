import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/domain/publication.dart';

enum ExchangeProposalStatus { pending, accepted, rejected }

class ExchangeProposal {
  const ExchangeProposal({
    required this.id,
    required this.requestedPublicationId,
    required this.requestedPublicationTitle,
    required this.requestedOwnerId,
    required this.offeredPublicationId,
    required this.offeredPublicationTitle,
    required this.offeredOwnerId,
    required this.status,
    required this.proposedAt,
    this.requestedImageUrl,
    this.offeredImageUrl,
    this.respondedAt,
    this.requestedOwnerConfirmedAt,
    this.offeredOwnerConfirmedAt,
  });

  final String id;
  final String requestedPublicationId;
  final String requestedPublicationTitle;
  final String requestedOwnerId;
  final String offeredPublicationId;
  final String offeredPublicationTitle;
  final String offeredOwnerId;
  final String? requestedImageUrl;
  final String? offeredImageUrl;
  final ExchangeProposalStatus status;
  final DateTime proposedAt;
  final DateTime? respondedAt;
  final DateTime? requestedOwnerConfirmedAt;
  final DateTime? offeredOwnerConfirmedAt;

  List<String> get participantIds => [requestedOwnerId, offeredOwnerId];

  bool hasConfirmed(String userId) {
    if (userId == requestedOwnerId) return requestedOwnerConfirmedAt != null;
    if (userId == offeredOwnerId) return offeredOwnerConfirmedAt != null;
    return false;
  }

  bool get bothConfirmed =>
      requestedOwnerConfirmedAt != null && offeredOwnerConfirmedAt != null;

  DateTime? get firstConfirmationAt {
    final requested = requestedOwnerConfirmedAt;
    final offered = offeredOwnerConfirmedAt;
    if (requested == null) return offered;
    if (offered == null) return requested;
    return requested.isBefore(offered) ? requested : offered;
  }

  PublicationStatus effectivePublicationStatus(DateTime now) {
    if (status != ExchangeProposalStatus.accepted) {
      return PublicationStatus.published;
    }
    if (bothConfirmed) return PublicationStatus.confirmed;

    final firstConfirmation = firstConfirmationAt;
    if (firstConfirmation == null) return PublicationStatus.committed;

    final elapsed = now.toUtc().difference(firstConfirmation.toUtc());
    if (elapsed >= const Duration(hours: 72)) {
      return PublicationStatus.closedWithoutConfirmation;
    }
    if (elapsed >= const Duration(hours: 48)) {
      return PublicationStatus.pendingConfirmation;
    }
    return PublicationStatus.delivered;
  }

  Map<String, Object?> toMap() => {
    'requestedPublicationId': requestedPublicationId,
    'requestedPublicationTitle': requestedPublicationTitle,
    'requestedOwnerId': requestedOwnerId,
    'offeredPublicationId': offeredPublicationId,
    'offeredPublicationTitle': offeredPublicationTitle,
    'offeredOwnerId': offeredOwnerId,
    'participantIds': participantIds,
    'requestedImageUrl': requestedImageUrl,
    'offeredImageUrl': offeredImageUrl,
    'status': status.wireValue,
    'proposedAt': Timestamp.fromDate(proposedAt),
    'respondedAt': respondedAt == null
        ? null
        : Timestamp.fromDate(respondedAt!),
    'requestedOwnerConfirmedAt': requestedOwnerConfirmedAt == null
        ? null
        : Timestamp.fromDate(requestedOwnerConfirmedAt!),
    'offeredOwnerConfirmedAt': offeredOwnerConfirmedAt == null
        ? null
        : Timestamp.fromDate(offeredOwnerConfirmedAt!),
  };

  factory ExchangeProposal.fromMap(String id, Map<String, Object?> map) {
    return ExchangeProposal(
      id: id,
      requestedPublicationId: map['requestedPublicationId'] as String? ?? '',
      requestedPublicationTitle:
          map['requestedPublicationTitle'] as String? ?? '',
      requestedOwnerId: map['requestedOwnerId'] as String? ?? '',
      offeredPublicationId: map['offeredPublicationId'] as String? ?? '',
      offeredPublicationTitle: map['offeredPublicationTitle'] as String? ?? '',
      offeredOwnerId: map['offeredOwnerId'] as String? ?? '',
      requestedImageUrl: map['requestedImageUrl'] as String?,
      offeredImageUrl: map['offeredImageUrl'] as String?,
      status: ExchangeProposalStatusWire.fromValue(map['status'] as String?),
      proposedAt:
          _readDate(map['proposedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      respondedAt: _readDate(map['respondedAt']),
      requestedOwnerConfirmedAt: _readDate(map['requestedOwnerConfirmedAt']),
      offeredOwnerConfirmedAt: _readDate(map['offeredOwnerConfirmedAt']),
    );
  }
}

extension ExchangeProposalStatusWire on ExchangeProposalStatus {
  String get wireValue => switch (this) {
    ExchangeProposalStatus.pending => 'pendiente',
    ExchangeProposalStatus.accepted => 'aceptada',
    ExchangeProposalStatus.rejected => 'rechazada',
  };

  String get label => switch (this) {
    ExchangeProposalStatus.pending => 'Pendiente',
    ExchangeProposalStatus.accepted => 'Aceptada',
    ExchangeProposalStatus.rejected => 'Rechazada',
  };

  static ExchangeProposalStatus fromValue(String? value) => switch (value) {
    'pendiente' => ExchangeProposalStatus.pending,
    'aceptada' => ExchangeProposalStatus.accepted,
    'rechazada' => ExchangeProposalStatus.rejected,
    _ => throw FormatException('Estado de propuesta inválido: $value'),
  };
}

DateTime? _readDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
