import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import 'form_step.dart';
import 'publish_draft_notifier.dart';

class AnalyzingStep extends ConsumerStatefulWidget {
  const AnalyzingStep({super.key});

  static const _minimumDuration = Duration(milliseconds: 1400);

  @override
  ConsumerState<AnalyzingStep> createState() => _AnalyzingStepState();
}

class _AnalyzingStepState extends ConsumerState<AnalyzingStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _goToForm();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _goToForm() async {
    await Future<void>.delayed(AnalyzingStep._minimumDuration);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const FormStep()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(publishDraftProvider).photos;
    final texts = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PulsingPhoto(
                controller: _controller,
                photo: photos.isEmpty ? null : photos.first,
              ),
              const SizedBox(height: 40),
              Text(
                'Analizando las fotografías',
                style: texts.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  'Estamos reconociendo el bien para completar su ficha.',
                  textAlign: TextAlign.center,
                  style: texts.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _Dots(controller: _controller),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingPhoto extends StatelessWidget {
  const _PulsingPhoto({required this.controller, this.photo});

  final AnimationController controller;
  final File? photo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final wave = Curves.easeInOut.transform(
            (controller.value * 2 <= 1)
                ? controller.value * 2
                : 2 - controller.value * 2,
          );

          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 150 + wave * 46,
                height: 150 + wave * 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.06 + wave * 0.06),
                ),
              ),
              Transform.scale(scale: 0.97 + wave * 0.05, child: child),
            ],
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: photo == null
              ? Container(
                  width: 132,
                  height: 132,
                  color: AppColors.border,
                  child: const Icon(Icons.image_outlined, size: 40),
                )
              : Image.file(
                  photo!,
                  width: 132,
                  height: 132,
                  fit: BoxFit.cover,
                  cacheWidth: 400,
                ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final phase = (controller.value + index * 0.2) % 1;
            final active = phase < 0.5;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.25),
              ),
            );
          }),
        );
      },
    );
  }
}
