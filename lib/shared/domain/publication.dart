import 'package:cloud_firestore/cloud_firestore.dart';

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

  bool get isAvailable => status == PublicationStatus.published;

  PublicationStatus effectiveStatus(DateTime now) {
    if (status != PublicationStatus.delivered) return status;
    final deliveredAt = statusDates[PublicationStatus.delivered];
    if (deliveredAt == null) return status;
    final elapsed = now.toUtc().difference(deliveredAt.toUtc());
    if (elapsed >= const Duration(hours: 72)) {
      return PublicationStatus.closedWithoutConfirmation;
    }
    if (elapsed >= const Duration(hours: 48)) {
      return PublicationStatus.pendingConfirmation;
    }
    return status;
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
          _readDate(map['publishedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      statusDates: _readStatusDates(map['statusDates']),
      exchangeProposalId: map['exchangeProposalId'] as String?,
      counterpartPublicationId: map['counterpartPublicationId'] as String?,
      counterpartUserId: map['counterpartUserId'] as String?,
      committedAt: _readDate(map['committedAt']),
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
      final date = _readDate(entry.value);
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

DateTime? _readDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
