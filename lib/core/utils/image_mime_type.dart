/// Tipo MIME de una imagen a partir de la extensión de su ruta.
/// Cualquier extensión no reconocida se trata como JPEG, que es lo que
/// produce `image_picker` al redimensionar.
String imageMimeType(String path) {
  return switch (path.split('.').last.toLowerCase()) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    _ => 'image/jpeg',
  };
}
