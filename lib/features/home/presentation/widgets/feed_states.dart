import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/mascot.dart';

/// Al arrancar, Firestore emite primero el snapshot de caché y enseguida el
/// del servidor. El aviso espera a que el estado de caché se sostenga; si el
/// servidor responde antes, el widget se descarta sin haberse mostrado
/// (HU08-12).
class FeedOfflineNotice extends StatefulWidget {
  const FeedOfflineNotice({super.key});

  static const _grace = Duration(seconds: 2);

  @override
  State<FeedOfflineNotice> createState() => _FeedOfflineNoticeState();
}

class _FeedOfflineNoticeState extends State<FeedOfflineNotice> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(FeedOfflineNotice._grace, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: !_visible
          ? const SizedBox(width: double.infinity)
          : Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cloud_off_outlined, color: AppColors.warning),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Mostrando datos guardados. El listado puede no estar actualizado.',
                      // El amarillo suave es igual en ambos modos: texto oscuro.
                      style: TextStyle(color: AppColors.onAccent),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Ningún resultado coincide con los filtros o la búsqueda (HU08-9). El caso
/// "todavía no hay publicaciones" no pasa por aquí: lo cubre la tarjeta que
/// invita a publicar. Va sin mascota porque esa tarjeta ya la trae y dos en
/// la misma pantalla confunden (D13).
class FeedEmptyResults extends StatelessWidget {
  const FeedEmptyResults({super.key, required this.onClearFilters});

  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nada por aquí',
              textAlign: TextAlign.center,
              style: texts.titleLarge?.copyWith(
                fontFamily: 'FreckleFace',
                fontSize: 28,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ninguna publicación coincide con lo que buscas. Prueba con otros filtros.',
              textAlign: TextAlign.center,
              style: texts.bodyLarge?.copyWith(
                color: context.appColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onClearFilters,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Quitar filtros'),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedLoadError extends StatelessWidget {
  const FeedLoadError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Mascot(pose: MascotPose.box, height: 130),
            const SizedBox(height: 16),
            const Text(
              'No pudimos cargar las publicaciones. Revisa tu conexión.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
