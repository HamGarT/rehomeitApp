import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/domain/publication.dart';
import '../../../../shared/widgets/mascot.dart';
import 'profile_publication_tile.dart';
import 'profile_stats.dart';

/// Piezas que el perfil propio y el público comparten. Las dos pantallas
/// tienen la misma estructura de slivers y solo cambian los textos, la pose
/// de la mascota y si la lista es propia.

/// Spinner de la lista mientras carga.
class ProfileLoadingSliver extends StatelessWidget {
  const ProfileLoadingSliver({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}

/// Fallo al leer la lista. Va en línea y no a pantalla completa porque el
/// resto del perfil sí se leyó: nombre, distrito y fecha no dependen de esta
/// consulta. Sin [onRetry] solo informa.
class ProfileLoadError extends StatelessWidget {
  const ProfileLoadError({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.appColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: context.appColors.textSecondary),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
                child: const Text('Reintentar'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Estado vacío con la mascota, el titular de marca y una explicación.
class ProfileEmptyState extends StatelessWidget {
  const ProfileEmptyState({
    super.key,
    required this.pose,
    required this.title,
    required this.message,
    this.mascotHeight = 130,
  });

  final MascotPose pose;
  final String title;
  final String message;

  /// El GIF dormido es vertical y necesita más alto que una pose horizontal
  /// para no quedar con un ancho desproporcionado.
  final double mascotHeight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 8),
      child: Column(
        children: [
          Mascot(pose: pose, height: mascotHeight),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontFamily: 'FreckleFace',
              fontSize: 24,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: context.appColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Cabecera de sección con el conteo y la lista de publicaciones debajo.
List<Widget> profilePublicationSlivers({
  required String title,
  required List<Publication> items,
  bool isOwn = false,
}) {
  final now = DateTime.now();
  return [
    SliverToBoxAdapter(
      child: ProfileSectionHeader(title: title, trailing: '${items.length}'),
    ),
    SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => ProfilePublicationTile(
          publication: items[index],
          status: items[index].effectiveStatus(now),
          isOwn: isOwn,
        ),
      ),
    ),
  ];
}
