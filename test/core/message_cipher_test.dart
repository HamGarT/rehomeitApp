import 'package:flutter_test/flutter_test.dart';

import 'package:rehomeitapp/core/crypto/message_cipher.dart';

void main() {
  final key = List<int>.generate(32, (index) => index * 7 % 256);
  final otherKey = List<int>.generate(32, (index) => index * 11 % 256);

  test(
    'cifra y descifra con la misma clave y nunca guarda el texto plano',
    () async {
      final cipher = MessageCipher(key);
      const plain = 'Coordinemos el recojo mañana a las 10, ¿te parece?';
      final stored = await cipher.encrypt(plain);

      expect(stored, startsWith(MessageCipher.prefix));
      expect(stored, isNot(contains('recojo')));
      expect(await cipher.decrypt(stored), plain);
      // Cada envío lleva un nonce nuevo: dos mensajes iguales no se parecen.
      expect(await cipher.encrypt(plain), isNot(stored));
    },
  );

  test('no descifra con otra clave, texto alterado ni sin prefijo', () async {
    final cipher = MessageCipher(key);
    final stored = await cipher.encrypt('hola');

    expect(await MessageCipher(otherKey).decrypt(stored), isNull);
    final tampered = '${stored.substring(0, stored.length - 4)}AAAA';
    expect(await cipher.decrypt(tampered), isNull);
    expect(await cipher.decrypt('hola'), isNull);
    expect(await cipher.decrypt('${MessageCipher.prefix}***'), isNull);
  });

  test('sin clave no envía y muestra lo guardado como no disponible', () async {
    final cipher = MessageCipher.unavailable();
    expect(cipher.isAvailable, isFalse);
    expect(() => cipher.encrypt('hola'), throwsStateError);
    expect(
      await cipher.decrypt(await MessageCipher(key).encrypt('hola')),
      isNull,
    );
  });
}
