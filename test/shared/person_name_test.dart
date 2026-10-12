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
  });
}
