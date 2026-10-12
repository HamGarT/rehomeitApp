/// Nombres y apellidos de una persona, separados para derivar el nombre
/// abreviado con el que se la identifica ante terceros: nombre de pila e
/// inicial del primer apellido (D07, HU20-13). Lo usan el registro y la
/// edición del perfil.
class PersonName {
  const PersonName({required this.firstNames, required this.lastNames});

  /// Parte una cadena única, como el `displayName` de Google, en primera
  /// palabra y resto. Es una aproximación: "Ana María Torres" queda como
  /// "Ana" / "María Torres" hasta que la persona lo corrija en su perfil.
  factory PersonName.split(String fullName) {
    final parts = _words(fullName);
    if (parts.isEmpty) {
      return const PersonName(firstNames: 'Usuario', lastNames: '');
    }
    return PersonName(
      firstNames: parts.first,
      lastNames: parts.skip(1).join(' '),
    );
  }

  final String firstNames;
  final String lastNames;

  static const maxLength = 60;

  String get full => [firstNames, lastNames]
      .where((part) => part.isNotEmpty)
      .join(' ');

  /// "Ana T.". Sin apellido queda solo el nombre de pila.
  String get short {
    final first = _words(firstNames);
    final last = _words(lastNames);
    if (first.isEmpty) return last.isEmpty ? 'Usuario' : last.first;
    if (last.isEmpty) return first.first;
    return '${first.first} ${last.first[0].toUpperCase()}.';
  }

  Map<String, String> toUserFields() => {
    'nombreCompleto': full,
    'nombres': firstNames,
    'apellidos': lastNames,
  };

  static List<String> _words(String value) => value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}
