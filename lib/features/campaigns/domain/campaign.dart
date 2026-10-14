import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/firestore_dates.dart';

enum CampaignStatus { active, closed }

extension CampaignStatusWire on CampaignStatus {
  String get wireValue => switch (this) {
    CampaignStatus.active => 'active',
    CampaignStatus.closed => 'closed',
  };

  String get label => switch (this) {
    CampaignStatus.active => 'Activa',
    CampaignStatus.closed => 'Cerrada',
  };
}

CampaignStatus _campaignStatusFromWire(Object? value) =>
    value == 'closed' ? CampaignStatus.closed : CampaignStatus.active;

class CampaignNeed {
  const CampaignNeed({
    required this.id,
    required this.name,
    required this.requiredQuantity,
    required this.contributedQuantity,
  });

  final String id;
  final String name;
  final int requiredQuantity;
  final int contributedQuantity;

  bool get isCovered => contributedQuantity >= requiredQuantity;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'requiredQuantity': requiredQuantity,
    'contributedQuantity': contributedQuantity,
  };

  factory CampaignNeed.fromMap(Map<String, Object?> map) => CampaignNeed(
    id: map['id'] as String? ?? '',
    name: map['name'] as String? ?? '',
    requiredQuantity: (map['requiredQuantity'] as num?)?.toInt() ?? 0,
    contributedQuantity: (map['contributedQuantity'] as num?)?.toInt() ?? 0,
  );
}

class CollectionPoint {
  const CollectionPoint({
    required this.name,
    required this.address,
    required this.openingHours,
  });

  final String name;
  final String address;
  final String openingHours;

  Map<String, Object?> toMap() => {
    'name': name,
    'address': address,
    'openingHours': openingHours,
  };

  factory CollectionPoint.fromMap(Map<String, Object?> map) => CollectionPoint(
    name: map['name'] as String? ?? '',
    address: map['address'] as String? ?? '',
    openingHours: map['openingHours'] as String? ?? '',
  );
}

class Campaign {
  const Campaign({
    required this.id,
    required this.organizationId,
    required this.organizationName,
    required this.title,
    required this.description,
    required this.district,
    required this.closeAt,
    required this.collectionPoint,
    required this.needs,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
    this.imageStoragePath,
    this.closedAt,
    this.closedBy,
    this.closureReason,
    this.hasPendingWrites = false,
  });

  final String id;
  final String organizationId;
  final String organizationName;
  final String title;
  final String description;
  final String district;
  final DateTime closeAt;
  final String? imageUrl;
  final String? imageStoragePath;
  final CollectionPoint collectionPoint;
  final List<CampaignNeed> needs;
  final CampaignStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;
  final String? closedBy;
  final String? closureReason;
  final bool hasPendingWrites;

  int get totalRequired =>
      needs.fold(0, (total, need) => total + need.requiredQuantity);

  int get totalContributed =>
      needs.fold(0, (total, need) => total + need.contributedQuantity);

  double get progressPercent =>
      totalRequired == 0 ? 0 : totalContributed / totalRequired * 100;

  double get progressForIndicator => (progressPercent / 100).clamp(0, 1);

  bool isClosedAt(DateTime now) =>
      status == CampaignStatus.closed || !now.toUtc().isBefore(closeAt.toUtc());

  CampaignStatus effectiveStatus(DateTime now) =>
      isClosedAt(now) ? CampaignStatus.closed : CampaignStatus.active;

  int daysRemaining(DateTime now) {
    if (isClosedAt(now)) return 0;
    final difference = closeAt.toUtc().difference(now.toUtc());
    return (difference.inSeconds / Duration.secondsPerDay).ceil();
  }

  bool canEdit({required String userId, required DateTime now}) =>
      organizationId == userId && !isClosedAt(now);

  Map<String, Object?> toMap() => {
    'organizationId': organizationId,
    'organizationName': organizationName,
    'title': title,
    'description': description,
    'district': district,
    'closeAt': Timestamp.fromDate(closeAt),
    'imageUrl': imageUrl,
    'imageStoragePath': imageStoragePath,
    'collectionPoint': collectionPoint.toMap(),
    'needs': needs.map((need) => need.toMap()).toList(growable: false),
    'status': status.wireValue,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'closedAt': closedAt == null ? null : Timestamp.fromDate(closedAt!),
    'closedBy': closedBy,
    'closureReason': closureReason,
  };

  factory Campaign.fromMap(
    String id,
    Map<String, Object?> map, {
    bool hasPendingWrites = false,
  }) {
    final fallback = DateTime.now().toUtc();
    final point = map['collectionPoint'];
    final rawNeeds = map['needs'];
    return Campaign(
      id: id,
      organizationId: map['organizationId'] as String? ?? '',
      organizationName: map['organizationName'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      district: map['district'] as String? ?? '',
      closeAt: readFirestoreDate(map['closeAt']) ?? fallback,
      imageUrl: map['imageUrl'] as String?,
      imageStoragePath: map['imageStoragePath'] as String?,
      collectionPoint: CollectionPoint.fromMap(
        point is Map ? Map<String, Object?>.from(point) : const {},
      ),
      needs: rawNeeds is List
          ? rawNeeds
                .whereType<Map>()
                .map(
                  (need) =>
                      CampaignNeed.fromMap(Map<String, Object?>.from(need)),
                )
                .toList(growable: false)
          : const [],
      status: _campaignStatusFromWire(map['status']),
      createdAt: readFirestoreDate(map['createdAt']) ?? fallback,
      updatedAt: readFirestoreDate(map['updatedAt']) ?? fallback,
      closedAt: readFirestoreDate(map['closedAt']),
      closedBy: map['closedBy'] as String?,
      closureReason: map['closureReason'] as String?,
      hasPendingWrites: hasPendingWrites,
    );
  }
}
