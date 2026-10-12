import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import 'sheet_handle.dart';

/// Hoja para elegir entre cámara y galería. La usan la publicación y la foto
/// de perfil (D10). Devuelve `null` si se cerró sin elegir.
Future<ImageSource?> showImageSourceSheet(
  BuildContext context, {
  String? gallerySubtitle,
}) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    builder: (_) => _ImageSourceSheet(gallerySubtitle: gallerySubtitle),
  );
}

class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet({this.gallerySubtitle});

  final String? gallerySubtitle;

  @override
  Widget build(BuildContext context) {
    final subtitle = gallerySubtitle;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          const SheetHandle(),
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(
              Icons.photo_camera_outlined,
              color: context.appColors.primary,
            ),
            title: const Text('Tomar fotografía'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          ListTile(
            leading: Icon(
              Icons.photo_library_outlined,
              color: context.appColors.primary,
            ),
            title: const Text('Elegir de la galería'),
            subtitle: subtitle == null ? null : Text(subtitle),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
