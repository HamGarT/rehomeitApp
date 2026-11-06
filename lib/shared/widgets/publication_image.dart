import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';

/// Cómo se resuelve la URL de una imagen de red. La app usa la caché en
/// disco de `cached_network_image`: `Image.network` solo guarda en memoria y
/// cada apertura volvía a descargar todas las fotos del feed. Las pruebas de
/// widgets lo sustituyen por `NetworkImage`, que el entorno de prueba
/// responde con 400 al instante; la caché depende de plugins que ahí no
/// existen y deja el indicador de carga girando para siempre.
final networkImageFactoryProvider =
    Provider<ImageProvider Function(String url)>(
      (ref) => CachedNetworkImageProvider.new,
    );

class PublicationImage extends ConsumerWidget {
  const PublicationImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (url == null || url!.isEmpty) return const _ImageFallback();
    return Image(
      image: ref.watch(networkImageFactoryProvider)(url!),
      fit: fit,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
      errorBuilder: (context, error, stackTrace) => const _ImageFallback(),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.border,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: context.appColors.textSecondary,
        ),
      ),
    );
  }
}
