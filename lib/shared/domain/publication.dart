import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/firestore_dates.dart';

enum PublicationMode { donation, exchange }

enum DeliveryType { owner, volunteer }

enum PublicationStatus {
  published,
  committed,
  pickedUp,
  delivered,
  confirmed,
  pendingConfirmation,
  closedWithoutConfirmation,
  cancelled,
  removed,
}

class ItemDetail {
  const ItemDetail({
    required this.name,
    required this.value,
    this.generatedByAi = false,
  });

  final String name;
  final String value;
  final bool generatedByAi;

  ItemDetail copyWith({String? name, String? value}) {
    return ItemDetail(
      name: name ?? this.name,
      value: value ?? this.value,
      generatedByAi: generatedByAi && name == null && value == null,
    );
  }

  Map<String, Object?> toMap() => {'name': name, 'value': value};

  factory ItemDetail.fromMap(Map<String, Object?> map) {
    return ItemDetail(
      name: map['name'] as String? ?? '',
      value: map['value'] as String? ?? '',
    );
  }
}

/// Un estado alcanzado y cuándo.
typedef PublicationMilestone = ({PublicationStatus status, DateTime at});

class Publication {
  const Publication({
    required this.id,
    required this.authorId,
    required this.title,
    required this.category,
    required this.condition,
    required this.description,
    required this.details,
    required this.district,
    required this.mode,
    required this.status,
    required this.images,
    required this.publishedAt,
    this.statusDates = const {},
    this.deliveryType,
    this.exchangeProposalId,
    this.counterpartPublicationId,
    this.counterpartUserId,
    this.committedAt,
    this.volunteerId,
    this.pickedUpAt,
    this.deliveredAt,
    this.deliveryEvidence,
  });

  final String id;
  final String authorId;
  final String title;
  final String category;
  final String condition;
  final String description;
  final List<ItemDetail> details;
  final String district;
  final PublicationMode mode;
  final DeliveryType? deliveryType;
  final PublicationStatus status;
  final List<String> images;
  final DateTime publishedAt;
  final Map<PublicationStatus, DateTime> statusDates;
  final String? exchangeProposalId;
  final String? counterpartPublicationId;
  final String? counterpartUserId;
  final DateTime? committedAt;
  final String? volunteerId;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DeliveryEvidence? deliveryEvidence;

  /// Plazos desde la entrega (HU13-12 y HU13-13). El segundo corre desde que
  /// venció el primero. Se derivan al consultar (D02), nunca se escriben.
  static const pendingConfirmationAfter = Duration(hours: 48);
  static const closeWithoutConfirmationAfter = Duration(hours: 48 + 72);

  bool get isAvailable => status == PublicationStatus.published;

  bool get isDonation => mode == PublicationMode.donation;

  bool isAuthor(String userId) => userId == authorId;

  bool isVolunteer(String userId) =>
      volunteerId != null && userId == volunteerId;

  bool canAssumePickup(String userId) =>
      isDonation &&
      deliveryType == DeliveryType.volunteer &&
      isAvailable &&
      !isAuthor(userId);

  bool canReleaseCommitment(String userId) =>
      isDonation &&
      status == PublicationStatus.committed &&
      (isAuthor(userId) || isVolunteer(userId));

  bool canConfirmHandoff(String userId) =>
      isDonation && status == PublicationStatus.committed && isAuthor(userId);

  bool canRegisterDelivery(String userId) =>
      isDonation &&
      ((status == PublicationStatus.pickedUp && isVolunteer(userId)) ||
          (deliveryType == DeliveryType.owner &&
              isAvailable &&
              isAuthor(userId)));

  bool canConfirmClose(String userId, DateTime now) =>
      isDonation &&
      deliveryType == DeliveryType.volunteer &&
      isAuthor(userId) &&
      status == PublicationStatus.delivered &&
      effectiveStatus(now) != PublicationStatus.closedWithoutConfirmation;

  bool canWithdraw(String userId) => isAvailable && isAuthor(userId);

  bool canProposeExchange(String userId) =>
      mode == PublicationMode.exchange && isAvailable && !isAuthor(userId);

  /// Con quién conversa [userId]: el autor, o su voluntario si es el autor.
  String? conversationCounterpart(String userId) =>
      isAuthor(userId) ? volunteerId : authorId;

  /// Hitos alcanzados; los de vencimiento se derivan de la entrega (D02).
  List<PublicationMilestone> milestones(DateTime now) {
    final reached = <PublicationMilestone>[
      (
        status: PublicationStatus.published,
        at: statusDates[PublicationStatus.published] ?? publishedAt,
      ),
      for (final step in const [
        PublicationStatus.committed,
        PublicationStatus.pickedUp,
        PublicationStatus.delivered,
        PublicationStatus.confirmed,
      ])
        if (statusDates[step] case final date?)
          // Un compromiso deshecho deja su fecha en el documento; si la
          // publicación volvió a estar disponible, ese hito ya no cuenta.
          if (step != PublicationStatus.committed || !isAvailable)
            (status: step, at: date),
    ];
    final deliveredAt = statusDates[PublicationStatus.delivered];
    final derived = effectiveStatus(now);
    if (deliveredAt != null && derived != PublicationStatus.delivered) {
      if (derived == PublicationStatus.pendingConfirmation ||
          derived == PublicationStatus.closedWithoutConfirmation) {
        reached.add((
          status: PublicationStatus.pendingConfirmation,
          at: deliveredAt.add(pendingConfirmationAfter),
        ));
      }
      if (derived == PublicationStatus.closedWithoutConfirmation) {
        reached.add((
          status: PublicationStatus.closedWithoutConfirmation,
          at: deliveredAt.add(closeWithoutConfirmationAfter),
        ));
      }
    }
    return reached;
  }

  PublicationStatus effectiveStatus(DateTime now) {
    if (status != PublicationStatus.delivered) return status;
    final deliveredAt = statusDates[PublicationStatus.delivered];
    if (deliveredAt == null) return status;
    return statusAfterDelivery(deliveredAt, now) ?? status;
  }

  /// Estado derivado del tiempo transcurrido desde [deliveredAt], o `null` si
  /// todavía no venció ningún plazo. Lo comparten donaciones e intercambios.
  static PublicationStatus? statusAfterDelivery(
    DateTime deliveredAt,
    DateTime now,
  ) {
    final elapsed = now.toUtc().difference(deliveredAt.toUtc());
    if (elapsed >= closeWithoutConfirmationAfter) {
      return PublicationStatus.closedWithoutConfirmation;
    }
    if (elapsed >= pendingConfirmationAfter) {
      return PublicationStatus.pendingConfirmation;
    }
    return null;
  }

  Map<String, Object?> toMap() => {
    'authorId': authorId,
    'title': title,
    'category': category,
    'condition': condition,
    'description': description,
    'details': details.map((detail) => detail.toMap()).toList(),
    'district': district,
    'mode': mode.wireValue,
    'deliveryType': deliveryType?.wireValue,
    'status': status.wireValue,
    'images': images,
    'publishedAt': Timestamp.fromDate(publishedAt),
    'statusDates': {
      for (final entry in statusDates.entries)
        entry.key.wireValue: Timestamp.fromDate(entry.value),
    },
    if (exchangeProposalId != null) 'exchangeProposalId': exchangeProposalId,
    if (counterpartPublicationId != null)
      'counterpartPublicationId': counterpartPublicationId,
    if (counterpartUserId != null) 'counterpartUserId': counterpartUserId,
    if (committedAt != null) 'committedAt': Timestamp.fromDate(committedAt!),
    if (volunteerId != null) 'volunteerId': volunteerId,
    if (pickedUpAt != null) 'pickedUpAt': Timestamp.fromDate(pickedUpAt!),
    if (deliveredAt != null) 'deliveredAt': Timestamp.fromDate(deliveredAt!),
    if (deliveryEvidence != null) 'deliveryEvidence': deliveryEvidence!.toMap(),
  };

  factory Publication.fromMap(String id, Map<String, Object?> map) {
    return Publication(
      id: id,
      authorId: map['authorId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      category: map['category'] as String? ?? '',
      condition: map['condition'] as String? ?? '',
      description: map['description'] as String? ?? '',
      details: _readDetails(map['details']),
      district: map['district'] as String? ?? '',
      mode: PublicationModeWire.fromValue(map['mode'] as String?),
      deliveryType: DeliveryTypeWire.fromNullableValue(
        map['deliveryType'] as String?,
      ),
      status: PublicationStatusWire.fromValue(map['status'] as String?),
      images: (map['images'] as List<Object?>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      publishedAt:
          readFirestoreDate(map['publishedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      statusDates: _readStatusDates(map['statusDates']),
      exchangeProposalId: map['exchangeProposalId'] as String?,
      counterpartPublicationId: map['counterpartPublicationId'] as String?,
      counterpartUserId: map['counterpartUserId'] as String?,
      committedAt: readFirestoreDate(map['committedAt']),
      volunteerId: map['volunteerId'] as String?,
      pickedUpAt: readFirestoreDate(map['pickedUpAt']),
      deliveredAt: readFirestoreDate(map['deliveredAt']),
      deliveryEvidence: map['deliveryEvidence'] is Map
          ? DeliveryEvidence.fromMap(
              (map['deliveryEvidence'] as Map).map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            )
          : null,
    );
  }

  static List<ItemDetail> _readDetails(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (detail) => ItemDetail.fromMap(
            detail.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  static Map<PublicationStatus, DateTime> _readStatusDates(Object? raw) {
    if (raw is! Map) return const {};
    final result = <PublicationStatus, DateTime>{};
    for (final entry in raw.entries) {
      final date = readFirestoreDate(entry.value);
      if (date == null) continue;
      try {
        result[PublicationStatusWire.fromValue(entry.key.toString())] = date;
      } on FormatException {
        // Permite incorporar futuros hitos sin romper clientes anteriores.
      }
    }
    return result;
  }
}

class DeliveryEvidence {
  const DeliveryEvidence({
    required this.recipientInitials,
    required this.district,
    required this.storagePath,
    required this.recordedAt,
  });

  final String recipientInitials;
  final String district;
  final String storagePath;
  final DateTime recordedAt;

  Map<String, Object?> toMap() => {
    'recipientInitials': recipientInitials,
    'district': district,
    'storagePath': storagePath,
    'recordedAt': Timestamp.fromDate(recordedAt),
  };

  factory DeliveryEvidence.fromMap(Map<String, Object?> map) {
    return DeliveryEvidence(
      recipientInitials: map['recipientInitials'] as String? ?? '',
      district: map['district'] as String? ?? '',
      storagePath: map['storagePath'] as String? ?? '',
      recordedAt:
          readFirestoreDate(map['recordedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

extension PublicationModeWire on PublicationMode {
  String get wireValue => switch (this) {
    PublicationMode.donation => 'donacion',
    PublicationMode.exchange => 'intercambio',
  };

  String get label => switch (this) {
    PublicationMode.donation => 'Donación',
    PublicationMode.exchange => 'Intercambio',
  };

  static PublicationMode fromValue(String? value) => switch (value) {
    'donacion' => PublicationMode.donation,
    'intercambio' => PublicationMode.exchange,
    _ => throw FormatException('Modalidad de publicación inválida: $value'),
  };
}

extension DeliveryTypeWire on DeliveryType {
  String get wireValue => switch (this) {
    DeliveryType.owner => 'donante',
    DeliveryType.volunteer => 'voluntario',
  };

  String get label => switch (this) {
    DeliveryType.owner => 'Entrega el donante',
    DeliveryType.volunteer => 'Recojo por voluntario',
  };

  static DeliveryType? fromNullableValue(String? value) => switch (value) {
    null => null,
    'donante' => DeliveryType.owner,
    'voluntario' => DeliveryType.volunteer,
    _ => throw FormatException('Forma de entrega inválida: $value'),
  };
}

extension PublicationStatusWire on PublicationStatus {
  String get wireValue => switch (this) {
    PublicationStatus.published => 'publicada',
    PublicationStatus.committed => 'comprometida',
    PublicationStatus.pickedUp => 'recogida',
    PublicationStatus.delivered => 'entregada',
    PublicationStatus.confirmed => 'confirmada',
    PublicationStatus.pendingConfirmation => 'pendiente_confirmacion',
    PublicationStatus.closedWithoutConfirmation => 'cerrada_sin_confirmacion',
    PublicationStatus.cancelled => 'anulada',
    PublicationStatus.removed => 'retirada',
  };

  String get label => switch (this) {
    PublicationStatus.published => 'Publicada',
    PublicationStatus.committed => 'Comprometida',
    PublicationStatus.pickedUp => 'Recogida',
    PublicationStatus.delivered => 'Entregada',
    PublicationStatus.confirmed => 'Confirmada',
    PublicationStatus.pendingConfirmation => 'Pendiente de confirmación',
    PublicationStatus.closedWithoutConfirmation => 'Cerrada sin confirmación',
    PublicationStatus.cancelled => 'Anulada',
    PublicationStatus.removed => 'Retirada',
  };

  static PublicationStatus fromValue(String? value) => switch (value) {
    'publicada' => PublicationStatus.published,
    'comprometida' => PublicationStatus.committed,
    'recogida' => PublicationStatus.pickedUp,
    'entregada' => PublicationStatus.delivered,
    'confirmada' => PublicationStatus.confirmed,
    'pendiente_confirmacion' => PublicationStatus.pendingConfirmation,
    'cerrada_sin_confirmacion' => PublicationStatus.closedWithoutConfirmation,
    'anulada' => PublicationStatus.cancelled,
    'retirada' => PublicationStatus.removed,
    _ => throw FormatException('Estado de publicación inválido: $value'),
  };
}
