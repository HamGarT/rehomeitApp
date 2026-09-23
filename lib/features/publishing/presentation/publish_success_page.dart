import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/mascot.dart';
import 'photos_step.dart';
import 'publish_draft_notifier.dart';

/// Cierre del flujo de publicación. Un momento de celebración en lugar de un
/// aviso pasajero: es cuando la persona acaba de dar algo.
class PublishSuccessPage extends ConsumerWidget {
  const PublishSuccessPage({super.key});

  static const _entrance = Duration(milliseconds: 700);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.accent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
          child: Column(
            children: [
              const Spacer(),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: _entrance,
                curve: Curves.elasticOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: const Mascot(pose: MascotPose.wave, height: 220),
              ),
              const SizedBox(height: 28),
              Text(
                '¡Listo!',
                style: texts.titleLarge?.copyWith(
                  fontFamily: 'FreckleFace',
                  fontSize: 44,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu bien ya está publicado y aparece en Explorar para quien lo necesite.',
                textAlign: TextAlign.center,
                style: texts.bodyLarge?.copyWith(
                  fontSize: 17,
                  height: 1.4,
                  color: AppColors.textPrimary.withValues(alpha: 0.8),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Ir a Explorar'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  ref.read(publishDraftProvider.notifier).reset();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const PhotosStep()),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Publicar otro bien'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
