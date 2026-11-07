import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/prohibited_content.dart';
import 'gemini_support.dart';

final photoScreeningServiceProvider = Provider<PhotoScreeningService>((ref) {
  // Mismo backend que la ficha de HU04 (Agent Platform con App Check, D12).
  return PhotoScreeningService.gemini(FirebaseAI.agentPlatform());
});

/// Envía las fotografías al modelo y devuelve el texto JSON de la respuesta.
typedef PhotoScreeningGenerator = Future<String?> Function(List<File> photos);

/// Revisión previa a subir una fotografía a Storage (D21): pregunta a Gemini
/// solo si hay contenido prohibido, sin pedir ficha. La usan la publicación
/// cuando el análisis de HU04 no dio veredicto y la evidencia de entrega.
class PhotoScreeningService {
  PhotoScreeningService(this._generate);

  factory PhotoScreeningService.gemini(FirebaseAI firebaseAI) {
    final model = firebaseAI.generativeModel(
      model: geminiModelName,
      systemInstruction: Content.system(_instructions),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: _responseSchema,
        temperature: 0,
      ),
    );
    return PhotoScreeningService((photos) async {
      final parts = <Part>[
        for (final photo in photos) await inlinePhotoPart(photo),
        const TextPart(_prompt),
      ];
      final response = await model.generateContent([Content.multi(parts)]);
      return response.text;
    });
  }

  /// Más corto que el análisis de la ficha (30 s): la respuesta es una lista
  /// vacía o de pocos valores, y la persona espera con el botón pulsado.
  static const timeout = Duration(seconds: 20);

  final PhotoScreeningGenerator _generate;

  /// Termina sin error si las fotografías pueden subirse. Lanza
  /// [PhotoScreeningException] con la causa en cualquier otro caso.
  Future<void> screen(List<File> photos) async {
    final List<ProhibitedContent> found;
    try {
      final text = await _generate(photos).timeout(timeout);
      if (text == null || text.isEmpty) {
        throw const PhotoScreeningException.unavailable();
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map) throw const PhotoScreeningException.unavailable();
      found = ProhibitedContent.parseList(decoded['prohibitedContent']);
    } on PhotoScreeningException {
      rethrow;
    } on TimeoutException catch (error) {
      logGeminiError('PhotoScreening', error);
      throw const PhotoScreeningException.timeout();
    } on FormatException catch (error) {
      logGeminiError('PhotoScreening', error);
      throw const PhotoScreeningException.unavailable();
    } on SocketException catch (error) {
      logGeminiError('PhotoScreening', error);
      throw const PhotoScreeningException.offline();
    } catch (error) {
      logGeminiError('PhotoScreening', error);
      if (looksLikeOfflineError(error)) {
        throw const PhotoScreeningException.offline();
      }
      throw const PhotoScreeningException.unavailable();
    }
    if (found.isNotEmpty) throw PhotoScreeningException.prohibited(found);
  }

  static final _responseSchema = Schema.object(
    properties: {
      'prohibitedContent': Schema.array(
        items: Schema.enumString(
          enumValues: [
            for (final content in ProhibitedContent.values) content.wireValue,
          ],
          description:
              'Datos sensibles o peligrosos visibles en las fotografías. Vacío si no hay ninguno.',
        ),
      ),
    },
  );

  static const _instructions =
      '''
Eres el filtro de privacidad y seguridad de una aplicación de donación e intercambio de bienes de segunda mano.
Revisas fotografías que una persona quiere subir y solo indicas si aparece contenido prohibido en prohibitedContent:
$prohibitedContentRules
- Si no aparece nada de lo anterior, devuelve la lista vacía.
- No describas ni transcribas lo que ves; solo clasifica.
''';

  static const _prompt = 'Revisa estas fotografías.';
}

enum PhotoScreeningCause { prohibited, offline, timeout, unavailable }

class PhotoScreeningException implements Exception {
  const PhotoScreeningException.prohibited(this.content)
    : cause = PhotoScreeningCause.prohibited;

  const PhotoScreeningException.offline()
    : cause = PhotoScreeningCause.offline,
      content = const [];

  const PhotoScreeningException.timeout()
    : cause = PhotoScreeningCause.timeout,
      content = const [];

  const PhotoScreeningException.unavailable()
    : cause = PhotoScreeningCause.unavailable,
      content = const [];

  final PhotoScreeningCause cause;

  /// Lo detectado cuando [cause] es `prohibited`; vacío en los demás casos.
  final List<ProhibitedContent> content;

  bool get prohibited => cause == PhotoScreeningCause.prohibited;

  String get contentDescription => ProhibitedContent.describe(content);
}
