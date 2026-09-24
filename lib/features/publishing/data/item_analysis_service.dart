import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/item_categories.dart';
import '../../../core/utils/image_mime_type.dart';
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
        model: _modelName,
        systemInstruction: Content.system(_instructions),
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: _responseSchema,
          temperature: 0.2,
        ),
      );

  // gemini-2.5-flash dejó de estar disponible para proyectos nuevos el 23 de
  // setiembre de 2026; el servicio indicó este reemplazo.
  static const _modelName = 'gemini-3.6-flash';

  /// HU04-6 fijaba 5 segundos. Se amplió a 30 el 23 de setiembre de 2026:
  /// la latencia que reporta Firebase (4 a 15 s) no incluye la subida de las
  /// fotografías ni la conexión en frío de la primera llamada del día, y el
  /// corte anterior descartaba respuestas que el servicio sí completaba.
  static const timeout = Duration(seconds: 30);

  /// La copia que va al modelo es más liviana que la foto publicada (1600 px):
  /// el lado corto se reduce a este tamaño y se recomprime. Menos bytes por
  /// subir y menos tokens por procesar sin afectar la calidad visible en la app.
  static const _analysisShortSide = 1024;
  static const _analysisQuality = 70;

  final GenerativeModel _model;

  Future<ItemSuggestion> analyze(List<File> photos) async {
    final parts = <Part>[
      for (final photo in photos) await _photoPart(photo),
      const TextPart(_prompt),
    ];

    final ItemSuggestion suggestion;
    try {
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
      throw const ItemAnalysisException.unavailable();
    }

    if (!suggestion.recognized) {
      throw const ItemAnalysisException.unrecognized();
    }
    return suggestion;
  }

  // Si la compresión falla (formato no soportado o plataforma sin plugin) se
  // envía la foto original: perder el análisis sería peor que subir más bytes.
  Future<InlineDataPart> _photoPart(File photo) async {
    try {
      final compressed = await FlutterImageCompress.compressWithFile(
        photo.path,
        minWidth: _analysisShortSide,
        minHeight: _analysisShortSide,
        quality: _analysisQuality,
        format: CompressFormat.jpeg,
      );
      if (compressed != null) {
        return InlineDataPart('image/jpeg', compressed);
      }
    } catch (error) {
      _log(error);
    }
    return InlineDataPart(imageMimeType(photo.path), await photo.readAsBytes());
  }

  // Solo en depuración: el usuario ve un aviso genérico, pero el equipo
  // necesita el error real del servicio para diagnosticar.
  void _log(Object error) {
    if (kDebugMode) {
      debugPrint('[ItemAnalysis] ${error.runtimeType}: $error');
    }
  }

  static final _responseSchema = Schema.object(
    properties: {
      'recognized': Schema.boolean(
        description: 'true solo si las fotografías muestran un bien físico identificable.',
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
      'title',
      'category',
      'condition',
      'description',
      'details',
    ],
  );

  static const _instructions = '''
Eres el asistente de una aplicación de donación e intercambio de bienes de segunda mano.
Analizas fotografías de un mismo bien y completas su ficha de publicación en español.
Reglas:
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
  const ItemAnalysisException(this.message);

  const ItemAnalysisException.timeout()
    : message =
          'El análisis tardó demasiado. Puedes completar la ficha manualmente.';

  const ItemAnalysisException.unrecognized()
    : message =
          'No se reconoció el bien en las fotografías. Puedes completar la ficha manualmente.';

  const ItemAnalysisException.offline()
    : message =
          'Sin conexión, no se pudo analizar las fotografías. Puedes completar la ficha manualmente.';

  const ItemAnalysisException.unavailable()
    : message =
          'No se pudo analizar las fotografías. Puedes completar la ficha manualmente.';

  final String message;
}
