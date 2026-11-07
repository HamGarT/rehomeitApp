import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../core/utils/image_mime_type.dart';

/// gemini-2.5-flash dejó de estar disponible para proyectos nuevos el 23 de
/// setiembre de 2026; el servicio indicó este reemplazo.
const geminiModelName = 'gemini-3.6-flash';

/// La copia que va al modelo es más liviana que la foto subida (1600 px): el
/// lado corto se reduce a este tamaño y se recomprime. Menos bytes por subir
/// y menos tokens por procesar sin afectar la calidad visible en la app.
const _shortSide = 1024;
const _quality = 70;

/// Fotografía lista para enviar a Gemini. Si la compresión falla (formato no
/// soportado o plataforma sin plugin) va la original: perder la llamada sería
/// peor que subir más bytes.
Future<InlineDataPart> inlinePhotoPart(File photo) async {
  try {
    final compressed = await FlutterImageCompress.compressWithFile(
      photo.path,
      minWidth: _shortSide,
      minHeight: _shortSide,
      quality: _quality,
      format: CompressFormat.jpeg,
    );
    if (compressed != null) {
      return InlineDataPart('image/jpeg', compressed);
    }
  } catch (error) {
    logGeminiError('inlinePhotoPart', error);
  }
  return InlineDataPart(imageMimeType(photo.path), await photo.readAsBytes());
}

/// El SDK envuelve la falta de red en sus propias excepciones (HU04-7); solo
/// el texto permite distinguirla de un fallo del servicio.
bool looksLikeOfflineError(Object error) {
  final detail = error.toString().toLowerCase();
  const hints = [
    'socketexception',
    'network',
    'connection',
    'host lookup',
    'unreachable',
    'offline',
  ];
  return hints.any(detail.contains);
}

/// Solo en depuración: el usuario ve un aviso genérico, pero el equipo
/// necesita el error real del servicio para diagnosticar.
void logGeminiError(String scope, Object error) {
  if (kDebugMode) {
    debugPrint('[$scope] ${error.runtimeType}: $error');
  }
}
