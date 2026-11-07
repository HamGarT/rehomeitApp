/// Contenido que la IA reconoce en una fotografía y que impide subirla
/// (documentos de identidad, tarjetas de pago, armas y rostros de personas).
/// Lo comparten la ficha de HU04 y la revisión previa a cualquier subida (D21).
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

  /// Lee la lista que devuelve el modelo ignorando valores desconocidos y
  /// repetidos, en el orden en que aparecen.
  static List<ProhibitedContent> parseList(Object? raw) {
    final parsed = <ProhibitedContent>{};
    if (raw is List) {
      for (final entry in raw.whereType<String>()) {
        final content = fromValue(entry);
        if (content != null) parsed.add(content);
      }
    }
    return parsed.toList(growable: false);
  }

  static String describe(List<ProhibitedContent> content) =>
      content.map((it) => it.label).join(', ');
}

/// Reglas del prompt para detectar contenido prohibido. Van en el mismo texto
/// en los dos modelos para que la ficha y la revisión no discrepen.
const prohibitedContentRules = '''
  - "documento_identidad" si se ve un DNI, carné, pasaporte, licencia de conducir, partida de nacimiento o cualquier documento con datos personales.
  - "tarjeta_pago" si se ve una tarjeta de crédito, débito o similar, aunque solo sea una parte.
  - "arma" si se ve un arma de fuego, munición o un arma blanca diseñada para atacar. No marques utensilios de cocina, herramientas ni juguetes evidentes.
  - "rostro" si se ve la cara o el rostro de cualquier persona, aunque sea parcial o aparezca de fondo. No lo marques si solo se ven manos o personas de espaldas.''';
