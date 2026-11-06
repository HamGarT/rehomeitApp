import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cifra el texto de los mensajes antes de escribirlo en Firestore (D19).
///
/// Es cifrado en reposo del lado del cliente con una clave de la app, no de
/// extremo a extremo: protege frente a quien lea la base desde la consola o
/// una exportación, y funciona en cualquier teléfono con la cuenta. La clave
/// llega al compilar con `--dart-define-from-file=secrets.json`; sin ella la
/// app no envía mensajes y muestra los existentes como no disponibles.
///
/// Formato guardado: `enc1:` + base64(nonce de 12 bytes + texto cifrado +
/// etiqueta de 16 bytes), AES-GCM de 256 bits. El prefijo permite cambiar el
/// esquema sin romper lo ya guardado y las reglas lo exigen para que ningún
/// cliente guarde texto plano.
class MessageCipher {
  MessageCipher(List<int> key) : _key = SecretKey(key);

  MessageCipher.unavailable() : _key = null;

  factory MessageCipher.fromEnvironment() {
    const encoded = String.fromEnvironment('MESSAGE_KEY');
    try {
      final bytes = base64.decode(encoded);
      if (bytes.length == _keyLength) return MessageCipher(bytes);
    } on FormatException catch (_) {}
    return MessageCipher.unavailable();
  }

  static const prefix = 'enc1:';
  static const _keyLength = 32;
  static const _nonceLength = 12;
  static const _macLength = 16;

  final SecretKey? _key;
  final AesGcm _algorithm = AesGcm.with256bits(nonceLength: _nonceLength);

  bool get isAvailable => _key != null;

  Future<String> encrypt(String plainText) async {
    final key = _key;
    if (key == null) {
      throw StateError('Esta compilación no tiene clave de mensajería.');
    }
    final box = await _algorithm.encrypt(
      utf8.encode(plainText),
      secretKey: key,
    );
    return '$prefix${base64.encode(box.concatenation())}';
  }

  /// `null` cuando no se puede leer: sin clave, sin el prefijo esperado,
  /// clave distinta o texto alterado.
  Future<String?> decrypt(String storedText) async {
    final key = _key;
    if (key == null || !storedText.startsWith(prefix)) return null;
    try {
      final box = SecretBox.fromConcatenation(
        base64.decode(storedText.substring(prefix.length)),
        nonceLength: _nonceLength,
        macLength: _macLength,
      );
      return utf8.decode(await _algorithm.decrypt(box, secretKey: key));
    } on FormatException catch (_) {
      return null;
    } on SecretBoxAuthenticationError catch (_) {
      return null;
    } on ArgumentError catch (_) {
      return null;
    }
  }
}

final messageCipherProvider = Provider<MessageCipher>(
  (ref) => MessageCipher.fromEnvironment(),
);
