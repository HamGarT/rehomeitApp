import '../../../core/constants/item_categories.dart';
import 'publish_draft.dart';

/// Contenido que la IA reconoce en las fotografías y que impide publicar
/// (documentos de identidad, tarjetas de pago, armas y rostros de personas).
enum ProhibitedContent {
  identityDocument('documento_identidad', 'documentos de identidad'),
  paymentCard('tarjeta_pago', 'tarjetas de crédito o débito'),
  weapon('arma', 'armas'),
  face('rostro', 'rostros o personas');

  const ProhibitedContent(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ProhibitedContent? fromValue(String? value) {
    for (final content in values) {
      if (content.wireValue == value) return content;
    }
    return null;
  }
}

/// Ficha y detalles propuestos por el servicio de IA a partir de las
/// fotografías (HU04 y HU05, resueltos en una sola llamada según D05).
class ItemSuggestion {
  const ItemSuggestion({
    required this.recognized,
    required this.title,
    required this.category,
    required this.condition,
    required this.description,
    required this.details,
    this.prohibitedContent = const [],
  });

  static const maxDetails = 4;

  /// `false` cuando las fotografías no muestran un bien identificable (HU04-8).
  final bool recognized;
  final String title;
  final String? category;
  final String? condition;
  final String description;
  final List<ItemDetail> details;

  /// Datos sensibles o peligrosos detectados en las fotografías. Si no está
  /// vacío, la publicación se bloquea antes de completar la ficha.
  final List<ProhibitedContent> prohibitedContent;

  factory ItemSuggestion.fromJson(Map<String, Object?> json) {
    final rawDetails = json['details'];
    final details = <ItemDetail>[
      if (rawDetails is List)
        for (final entry in rawDetails.whereType<Map>())
          ItemDetail(
            name: _text(entry['name']),
            value: _text(entry['value']),
            generatedByAi: true,
          ),
    ];

    final rawProhibited = json['prohibitedContent'];
    final prohibited = <ProhibitedContent>{};
    if (rawProhibited is List) {
      for (final entry in rawProhibited.whereType<String>()) {
        final content = ProhibitedContent.fromValue(entry);
        if (content != null) prohibited.add(content);
      }
    }

    return ItemSuggestion(
      recognized: json['recognized'] == true,
      title: _text(json['title']),
      // El esquema ya restringe ambos a la lista, pero se valida igual para
      // que un valor inesperado nunca llegue a un desplegable.
      category: _inList(json['category'], ItemCategories.all),
      condition: _inList(json['condition'], ItemConditions.all),
      description: _text(json['description']),
      details: details
          .where((detail) => detail.name.isNotEmpty && detail.value.isNotEmpty)
          .take(maxDetails)
          .toList(growable: false),
      prohibitedContent: prohibited.toList(growable: false),
    );
  }

  static String _text(Object? value) => value is String ? value.trim() : '';

  static String? _inList(Object? value, List<String> allowed) {
    return value is String && allowed.contains(value) ? value : null;
  }
}
