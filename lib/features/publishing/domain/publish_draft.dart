import 'dart:io';

enum PublishMode { donation, exchange }

enum DeliveryMethod { owner, volunteer }

enum AiField { title, category, condition, description }

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
      // Editar un detalle sugerido lo convierte en propio del usuario.
      generatedByAi: generatedByAi && name == null && value == null,
    );
  }
}

class PublishDraft {
  const PublishDraft({
    this.photos = const [],
    this.title = '',
    this.category,
    this.condition,
    this.description = '',
    this.details = const [],
    this.district,
    this.mode,
    this.deliveryMethod,
    this.aiFields = const {},
  });

  static const maxPhotos = 4;
  static const maxDetails = 6;

  final List<File> photos;
  final String title;
  final String? category;
  final String? condition;
  final String description;
  final List<ItemDetail> details;
  final String? district;
  final PublishMode? mode;
  final DeliveryMethod? deliveryMethod;
  final Set<AiField> aiFields;

  bool get canAddPhoto => photos.length < maxPhotos;

  bool get canAddDetail => details.length < maxDetails;

  bool get photosCompleted => photos.isNotEmpty;

  List<String> get missingFormFields => [
    if (title.trim().isEmpty) 'Título',
    if (category == null) 'Categoría',
    if (condition == null) 'Estado del bien',
    if (description.trim().isEmpty) 'Descripción',
    if (district == null) 'Distrito de publicación',
  ];

  List<String> get missingModeFields => [
    if (mode == null) 'Modalidad del bien',
    if (mode == PublishMode.donation && deliveryMethod == null)
      'Forma de entrega',
  ];

  bool get formCompleted => missingFormFields.isEmpty;

  bool get modeCompleted => missingModeFields.isEmpty;

  PublishDraft copyWith({
    List<File>? photos,
    String? title,
    String? category,
    String? condition,
    String? description,
    List<ItemDetail>? details,
    String? district,
    PublishMode? mode,
    DeliveryMethod? deliveryMethod,
    Set<AiField>? aiFields,
  }) {
    return PublishDraft(
      photos: photos ?? this.photos,
      title: title ?? this.title,
      category: category ?? this.category,
      condition: condition ?? this.condition,
      description: description ?? this.description,
      details: details ?? this.details,
      district: district ?? this.district,
      mode: mode ?? this.mode,
      // Cambiar a intercambio descarta la forma de entrega, que solo aplica a donación.
      deliveryMethod: mode == PublishMode.exchange
          ? null
          : deliveryMethod ?? this.deliveryMethod,
      aiFields: aiFields ?? this.aiFields,
    );
  }
}
