import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/item_categories.dart';
import '../../../shared/data/gemini_support.dart';
import '../../../shared/domain/prohibited_content.dart';
import '../domain/item_suggestion.dart';

final itemAnalysisServiceProvider = Provider<ItemAnalysisService>((ref) {
  // Backend Agent Platform (antes Vertex AI): cobra a la cuenta de facturación
  // del proyecto en vez del prepago de la Gemini Developer API, cuyo saldo
  // llegó a cero el 23 de setiembre de 2026. App Check es obligatorio (D12);
  // el SDK adjunta el token solo porque se activa en main.dart.
  return ItemAnalysisService(FirebaseAI.agentPlatform());
});

/// Una única llamada a Gemini devuelve la ficha principal y los detalles
/// (D05). Las credenciales las gestiona Firebase AI Logic, no la app (HU04-11).
class ItemAnalysisService {
  ItemAnalysisService(FirebaseAI firebaseAI)
    : _model = firebaseAI.generativeModel(
        model: geminiModelName,
        systemInstruction: Content.system(_instructions),
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: _responseSchema,
          temperature: 0.2,
        ),
      );

  /// HU04-6 fija 30 segundos (partió de 10): la latencia que reporta Firebase
  /// (4 a 15 s) no incluye la subida de las fotografías ni la conexión en frío
  /// de la primera llamada del día, y el corte anterior descartaba respuestas
  /// que el servicio sí completaba.
  static const timeout = Duration(seconds: 30);

  final GenerativeModel _model;

  Future<ItemSuggestion> analyze(List<File> photos) async {
    final ItemSuggestion suggestion;
    try {
      // La lectura de las fotos va dentro del try: un error de E/S que no se
      // traduzca a ItemAnalysisException dejaría la pantalla de análisis sin
      // salida (HU04-7).
      final parts = <Part>[
        for (final photo in photos) await inlinePhotoPart(photo),
        const TextPart(_prompt),
      ];
      final response = await _model
          .generateContent([Content.multi(parts)])
          .timeout(timeout);
      final text = response.text;
      if (text == null || text.isEmpty) {
        throw const ItemAnalysisException.unrecognized();
      }
      suggestion = ItemSuggestion.fromJson(
        jsonDecode(text) as Map<String, Object?>,
      );
    } on ItemAnalysisException {
      rethrow;
    } on TimeoutException catch (error) {
      _log(error);
      throw const ItemAnalysisException.timeout();
    } on FormatException catch (error) {
      _log(error);
      throw const ItemAnalysisException.unrecognized();
    } on SocketException catch (error) {
      _log(error);
      throw const ItemAnalysisException.offline();
    } catch (error) {
      _log(error);
      if (looksLikeOfflineError(error)) {
        throw const ItemAnalysisException.offline();
      }
      throw const ItemAnalysisException.unavailable();
    }

    if (suggestion.prohibitedContent.isNotEmpty) {
      throw ItemAnalysisException.prohibitedContent(
        suggestion.prohibitedContent,
      );
    }
    if (!suggestion.recognized) {
      throw const ItemAnalysisException.unrecognized(hasVerdict: true);
    }
    return suggestion;
  }

  void _log(Object error) => logGeminiError('ItemAnalysis', error);

  static final _responseSchema = Schema.object(
    properties: {
      'recognized': Schema.boolean(
        description: 'true solo si las fotografías muestran un bien físico identificable.',
      ),
      'prohibitedContent': Schema.array(
        items: Schema.enumString(
          enumValues: [
            for (final content in ProhibitedContent.values) content.wireValue,
          ],
          description: 'Datos sensibles o peligrosos visibles en las fotografías. Vacío si no hay ninguno.',
        ),
      ),
      'title': Schema.string(
        description: 'Nombre corto del bien, máximo 60 caracteres.',
      ),
      'category': Schema.enumString(enumValues: ItemCategories.all),
      'condition': Schema.enumString(enumValues: ItemConditions.all),
      'description': Schema.string(
        description: 'Dos o tres oraciones sobre el bien y su estado.',
      ),
      'details': Schema.array(
        maxItems: ItemSuggestion.maxDetails,
        items: Schema.object(
          properties: {
            'name': Schema.string(description: 'Nombre del campo.'),
            'value': Schema.string(description: 'Valor observado.'),
          },
        ),
      ),
    },
    propertyOrdering: [
      'recognized',
      'prohibitedContent',
      'title',
      'category',
      'condition',
      'description',
      'details',
    ],
  );

  static const _instructions =
      '''
Eres el asistente de una aplicación de donación e intercambio de bienes de segunda mano.
Analizas fotografías de un mismo bien y completas su ficha de publicación en español.
Reglas:
- Antes que nada, revisa si aparece contenido prohibido y complétalo en prohibitedContent:
$prohibitedContentRules
- Si hay contenido prohibido, devuélvelo en prohibitedContent y deja recognized=false y los demás campos vacíos. No describas ni transcribas los datos sensibles.
- Si las fotografías no muestran un bien físico identificable, devuelve recognized=false y deja los demás campos vacíos.
- El título es breve y concreto, sin adjetivos de venta.
- El estado se deduce de lo visible: "Nuevo" con etiqueta o empaque, "Como nuevo" sin marcas de uso, "Usado" con señales de uso.
- Los detalles son características propias del tipo de bien, con nombre de campo y valor. Por ejemplo, talla y marca para una prenda, material y dimensiones para un mueble, color y modelo para tecnología. Incluye solo los que se puedan observar, hasta cuatro.
- Los nombres de campo van con la primera letra en mayúscula y el resto en minúscula, sin dos puntos.
- No inventes datos que no se vean en las fotografías.
''';

  static const _prompt = 'Completa la ficha de este bien.';
}

class ItemAnalysisException implements Exception {
  const ItemAnalysisException(
    this.message, {
    this.blocksPublishing = false,
    this.hasVerdict = false,
  });

  ItemAnalysisException.prohibitedContent(List<ProhibitedContent> content)
    : message =
          'No puedes publicar este bien: las fotografías muestran ${ProhibitedContent.describe(content)}. '
          'Retira esas imágenes e inténtalo de nuevo.',
      blocksPublishing = true,
      hasVerdict = true;

  const ItemAnalysisException.timeout()
    : message =
          'El análisis tardó demasiado. Puedes completar la ficha manualmente.',
      blocksPublishing = false,
      hasVerdict = false;

  /// [hasVerdict] solo cuando el modelo respondió que no hay bien; una
  /// respuesta vacía o ilegible usa el mismo aviso pero no cuenta como revisión.
  const ItemAnalysisException.unrecognized({this.hasVerdict = false})
    : message =
          'No se reconoció el bien en las fotografías. Puedes completar la ficha manualmente.',
      blocksPublishing = false;

  const ItemAnalysisException.offline()
    : message =
          'Sin conexión, no se pudo analizar las fotografías. Puedes completar la ficha manualmente.',
      blocksPublishing = false,
      hasVerdict = false;

  const ItemAnalysisException.unavailable()
    : message =
          'No se pudo analizar las fotografías. Puedes completar la ficha manualmente.',
      blocksPublishing = false,
      hasVerdict = false;

  final String message;

  /// `true` cuando el contenido detectado impide continuar con la publicación.
  final bool blocksPublishing;

  /// `true` cuando el modelo llegó a revisar las fotografías, aunque no haya
  /// ficha: publicar no necesita revisarlas otra vez (D21).
  final bool hasVerdict;
}
