import 'package:flutter_test/flutter_test.dart';
import 'package:rehomeitapp/shared/domain/person_name.dart';

void main() {
  group('PersonName', () {
    test('el nombre corto es nombre de pila e inicial del primer apellido', () {
      const name = PersonName(
        firstNames: 'Ana María',
        lastNames: 'Torres Quispe',
      );
      expect(name.short, 'Ana T.');
      expect(name.full, 'Ana María Torres Quispe');
    });

    test('sin apellido queda solo el nombre de pila', () {
      const name = PersonName(firstNames: 'Ana', lastNames: '');
      expect(name.short, 'Ana');
      expect(name.full, 'Ana');
      expect(name.toUserFields()['nombreCompleto'], 'Ana');
    });

    test('partir una cadena toma la primera palabra como nombre', () {
      final name = PersonName.split('  Luis  Quispe Vargas ');
      expect(name.firstNames, 'Luis');
      expect(name.lastNames, 'Quispe Vargas');
      expect(name.short, 'Luis Q.');
      expect(PersonName.split('').firstNames, 'Usuario');
    });

    test('los candidatos suman letras del apellido, luego el segundo '
        'apellido y al final un número', () {
      const name = PersonName(firstNames: 'Hamer', lastNames: 'Gil Ramos');
      expect(name.shortCandidates.take(6), [
        'Hamer G.',
        'Hamer Gi.',
        'Hamer Gil',
        'Hamer Gil R.',
        'Hamer Gil R 2',
        'Hamer Gil R 3',
      ]);
    });

    test('sin apellido los candidatos pasan directo al número', () {
      const name = PersonName(firstNames: 'Hamer', lastNames: '');
      expect(name.shortCandidates.take(3), ['Hamer', 'Hamer 2', 'Hamer 3']);
    });

    test('ningún candidato repite clave ni supera el largo de las reglas', () {
      final name = PersonName(firstNames: 'Ana', lastNames: 'T${'o' * 70}');
      final candidates = name.shortCandidates;
      expect(
        candidates.every((c) => c.length <= PersonName.maxShortLength),
        isTrue,
      );
      expect(
        candidates.map(PersonName.shortNameKey).toSet().length,
        candidates.length,
      );
    });

    test('la barra no llega al nombre corto, que es el id de su reserva', () {
      const name = PersonName(firstNames: 'Ana/María', lastNames: 'T/orres');
      expect(name.shortCandidates.any((c) => c.contains('/')), isFalse);
    });
  });
}
