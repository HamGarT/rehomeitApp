import '../../../core/utils/firestore_dates.dart';

enum ContributionStatus { pending, confirmed, rejected }

extension ContributionStatusWire on ContributionStatus {
  String get wireValue => switch (this) {
    ContributionStatus.pending => 'pendiente',
    ContributionStatus.confirmed => 'confirmado',
    ContributionStatus.rejected => 'rechazado',
  };

  String get label => switch (this) {
    ContributionStatus.pending => 'Pendiente',
    ContributionStatus.confirmed => 'Confirmado',
    ContributionStatus.rejected => 'Rechazado',
  };
}

ContributionStatus _contributionStatusFromWire(Object? value) =>
    switch (value) {
      'confirmado' => ContributionStatus.confirmed,
      'rechazado' => ContributionStatus.rejected,
      _ => ContributionStatus.pending,
    };

class Contribution {
  const Contribution({
    required this.id,
    required this.campaignId,
    required this.campaignTitle,
    required this.organizationId,
    required this.needId,
    required this.needName,
    required this.quantity,
    required this.contributorId,
    required this.contributorName,
    required this.status,
    required this.createdAt,
    this.confirmedAt,
    this.confirmedBy,
    this.rejectedAt,
    this.rejectedBy,
    this.rejectionReason,
    this.hasPendingWrites = false,
  });

  final String id;
  final String campaignId;
  final String campaignTitle;
  final String organizationId;
  final String needId;
  final String needName;
  final int quantity;
  final String contributorId;
  final String contributorName;
  final ContributionStatus status;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final String? confirmedBy;
  final DateTime? rejectedAt;
  final String? rejectedBy;
  final String? rejectionReason;
  final bool hasPendingWrites;

  bool get isPending => status == ContributionStatus.pending;
  bool get isConfirmed => status == ContributionStatus.confirmed;
  bool get isRejected => status == ContributionStatus.rejected;

  factory Contribution.fromMap(
    String id,
    Map<String, Object?> map, {
    bool hasPendingWrites = false,
  }) => Contribution(
    id: id,
    campaignId: map['campaignId'] as String? ?? '',
    campaignTitle: map['campaignTitle'] as String? ?? '',
    organizationId: map['organizationId'] as String? ?? '',
    needId: map['needId'] as String? ?? '',
    needName: map['needName'] as String? ?? '',
    quantity: (map['quantity'] as num?)?.toInt() ?? 0,
    contributorId: map['contributorId'] as String? ?? '',
    contributorName: map['contributorName'] as String? ?? '',
    status: _contributionStatusFromWire(map['status']),
    createdAt: readFirestoreDate(map['createdAt']) ?? DateTime.now().toUtc(),
    confirmedAt: readFirestoreDate(map['confirmedAt']),
    confirmedBy: map['confirmedBy'] as String?,
    rejectedAt: readFirestoreDate(map['rejectedAt']),
    rejectedBy: map['rejectedBy'] as String?,
    rejectionReason: map['rejectionReason'] as String?,
    hasPendingWrites: hasPendingWrites,
  );
}
