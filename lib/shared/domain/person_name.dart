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

  /// Largo máximo del nombre corto que admiten las reglas.
  static const maxShortLength = 60;

  /// Cuántos candidatos numerados se ofrecen cuando las letras no alcanzan.
  static const _numberedCandidates = 30;

  /// Nombres cortos posibles, del preferido al último recurso. El nombre
  /// corto es único (D07): quien llega segundo suma letras del apellido
  /// ("Ana T.", "Ana To.", ..., "Ana Torres"), luego la inicial del segundo
  /// apellido y, si todo está tomado, un número ("Ana Torres 2").
  List<String> get shortCandidates {
    final first = _words(firstNames);
    final last = _words(lastNames);
    final candidates = <String>[short];
    if (first.isNotEmpty && last.isNotEmpty) {
      final given = first.first;
      final surname = last.first;
      for (var length = 2; length < surname.length; length++) {
        candidates.add('$given ${_capitalize(surname.substring(0, length))}.');
      }
      final withSurname = '$given ${_capitalize(surname)}';
      candidates.add(withSurname);
      if (last.length > 1) {
        candidates.add('$withSurname ${last[1][0].toUpperCase()}.');
      }
    }
    final fitting = candidates
        .where((candidate) => candidate.length <= maxShortLength)
        .toSet()
        .toList();
    var base = _withoutTrailingDot(fitting.isEmpty ? short : fitting.last);
    if (base.length > maxShortLength - _numberSuffixLength) {
      base = base.substring(0, maxShortLength - _numberSuffixLength).trimRight();
    }
    return [
      ...fitting,
      for (var number = 2; number < 2 + _numberedCandidates; number++)
        '$base $number',
    ];
  }

  /// Espacio y hasta dos cifras al final de un candidato numerado.
  static const _numberSuffixLength = 3;

  /// Clave con la que se reserva un nombre corto. Las reglas la calculan
  /// igual (`lower()`), así que no puede normalizar nada más.
  static String shortNameKey(String shortName) => shortName.toLowerCase();

  static String _capitalize(String word) =>
      word[0].toUpperCase() + word.substring(1);

  static String _withoutTrailingDot(String value) =>
      value.endsWith('.') ? value.substring(0, value.length - 1) : value;

  Map<String, String> toUserFields() => {
    'nombreCompleto': full,
    'nombres': firstNames,
    'apellidos': lastNames,
  };

  // La barra se descarta: el nombre corto es también el id de su reserva y
  // Firestore no admite barras en un id.
  static List<String> _words(String value) => value
      .replaceAll('/', ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}
