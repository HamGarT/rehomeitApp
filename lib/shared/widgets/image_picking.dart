import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import 'app_snack_bar.dart';

/// Códigos con los que `image_picker` avisa que la persona negó el permiso.
/// El de cámara lo emiten Android e iOS; el de fotos solo iOS, porque Android
/// usa el selector del sistema y no pide permiso.
const _cameraDenied = 'camera_access_denied';
const _photosDenied = 'photo_access_denied';

const _cameraDeniedMessage =
    'Permite el acceso a la cámara en los ajustes del teléfono para tomar la fotografía.';
const _photosDeniedMessage =
    'Permite el acceso a tus fotos en los ajustes del teléfono para elegir una imagen.';

/// Abre la cámara o la galería y, si el permiso fue negado, lo explica con un
/// snackbar en vez de dejar escapar la excepción. Devuelve `null` también
/// cuando la persona cierra el selector sin elegir, que es lo que ya hacía
/// `pickImage`; quien llama no distingue ambos casos porque en los dos no hay
/// nada que guardar.
Future<XFile?> pickImageOrExplain(
  BuildContext context, {
  required ImageSource source,
  double? maxWidth,
  int? imageQuality,
}) async {
  try {
    return await ImagePicker().pickImage(
      source: source,
      maxWidth: maxWidth,
      imageQuality: imageQuality,
    );
  } on PlatformException catch (error) {
    if (!_explainDenial(context, error)) rethrow;
    return null;
  }
}

/// Variante de galería múltiple con el mismo trato a la negación de permiso.
Future<List<XFile>> pickMultiImageOrExplain(
  BuildContext context, {
  required int limit,
  double? maxWidth,
  int? imageQuality,
}) async {
  try {
    return await ImagePicker().pickMultiImage(
      limit: limit,
      maxWidth: maxWidth,
      imageQuality: imageQuality,
    );
  } on PlatformException catch (error) {
    if (!_explainDenial(context, error)) rethrow;
    return const [];
  }
}

/// `true` si el error era una negación de permiso y ya se mostró el aviso.
bool _explainDenial(BuildContext context, PlatformException error) {
  final message = switch (error.code) {
    _cameraDenied => _cameraDeniedMessage,
    _photosDenied => _photosDeniedMessage,
    _ => null,
  };
  if (message == null) return false;
  if (context.mounted) {
    showAppSnackBar(context, message, kind: AppSnackBarKind.error);
  }
  return true;
}
