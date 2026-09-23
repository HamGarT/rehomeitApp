import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/mascot.dart';
import 'form_step.dart';
import 'publish_draft_notifier.dart';

class AnalyzingStep extends ConsumerStatefulWidget {
  const AnalyzingStep({super.key});

  static const _perPhoto = Duration(milliseconds: 950);
  static const _minimumDuration = Duration(milliseconds: 1400);

  @override
  ConsumerState<AnalyzingStep> createState() => _AnalyzingStepState();
}

class _AnalyzingStepState extends ConsumerState<AnalyzingStep>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _scan;
  Timer? _rotation;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _scan = AnimationController(vsync: this, duration: AnalyzingStep._perPhoto)
      ..repeat();
    _rotation = Timer.periodic(AnalyzingStep._perPhoto, _showNextPhoto);
    _goToForm();
  }

  @override
  void dispose() {
    _rotation?.cancel();
    _scan.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _showNextPhoto(Timer _) {
    final total = ref.read(publishDraftProvider).photos.length;
    if (total < 2) return;
    setState(() => _index = (_index + 1) % total);
  }

  Future<void> _goToForm() async {
    // El análisis y el recorrido de fotografías corren a la vez; se avanza
    // cuando ambos terminan, así la pantalla nunca parpadea con una respuesta
    // rápida ni se corta con una lenta.
    final analysis = ref.read(publishDraftProvider.notifier).analyzePhotos();
    await Future<void>.delayed(_analysisDuration());
    final failureMessage = await analysis;
    if (!mounted) return;

    if (failureMessage != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failureMessage)));
    }
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const FormStep()));
  }

  // La espera alcanza para mostrar cada fotografía una vez.
  Duration _analysisDuration() {
    final photos = ref.read(publishDraftProvider).photos.length;
    final tour = AnalyzingStep._perPhoto * photos;
    return tour < AnalyzingStep._minimumDuration
        ? AnalyzingStep._minimumDuration
        : tour;
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(publishDraftProvider).photos;
    final texts = Theme.of(context).textTheme;
    final current = _index < photos.length ? photos[_index] : null;

    // Superficie de marca: el cuy con la caja "recibe" el bien mientras la
    // IA lo reconoce. El anillo con las fotos se mantiene porque muestra qué
    // se está analizando.
    return Scaffold(
      backgroundColor: AppColors.accent,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Mascot(pose: MascotPose.box, height: 150),
              const SizedBox(height: 18),
              _PhotoStage(
                pulse: _pulse,
                scan: _scan,
                photo: current,
                photoKey: _index,
              ),
              const SizedBox(height: 28),
              Text(
                'Analizando las fotografías',
                textAlign: TextAlign.center,
                style: texts.titleLarge?.copyWith(
                  fontFamily: 'FreckleFace',
                  fontSize: 30,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  'Estamos reconociendo el bien para completar su ficha.',
                  textAlign: TextAlign.center,
                  style: texts.bodyLarge?.copyWith(
                    color: AppColors.textPrimary.withValues(alpha: 0.75),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _PhotoIndicator(count: photos.length, active: _index),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoStage extends StatelessWidget {
  const _PhotoStage({
    required this.pulse,
    required this.scan,
    required this.photoKey,
    this.photo,
  });

  final AnimationController pulse;
  final AnimationController scan;
  final File? photo;
  final int photoKey;

  static const _stage = 210.0;
  static const _ring = 176.0;
  static const _photo = 148.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _stage,
      height: _stage,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          final wave = Curves.easeInOut.transform(
            (pulse.value * 2 <= 1) ? pulse.value * 2 : 2 - pulse.value * 2,
          );

          return Stack(
            alignment: Alignment.center,
            children: [
              // Sobre el amarillo, la onda se ve mejor en blanco que en marrón.
              Container(
                width: 162 + wave * 44,
                height: 162 + wave * 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface.withValues(alpha: 0.25 + wave * 0.2),
                ),
              ),
              SizedBox(
                width: _ring,
                height: _ring,
                child: AnimatedBuilder(
                  animation: scan,
                  builder: (context, _) =>
                      CustomPaint(painter: _RingPainter(progress: scan.value)),
                ),
              ),
              child!,
            ],
          );
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.88, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: SizedBox(
            key: ValueKey(photoKey),
            width: _photo,
            height: _photo,
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (photo == null)
                    Container(
                      color: AppColors.border,
                      child: const Icon(Icons.image_outlined, size: 40),
                    )
                  else
                    Image.file(photo!, fit: BoxFit.cover, cacheWidth: 400),
                  _ScanLine(controller: scan),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanLine extends StatelessWidget {
  const _ScanLine({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // Arranca y termina fuera del círculo para que no se vea aparecer.
        final travel = Curves.easeInOut.transform(controller.value) * 2.6 - 1.3;
        return Align(alignment: Alignment(0, travel), child: child);
      },
      child: FractionallySizedBox(
        heightFactor: 0.3,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withValues(alpha: 0),
                AppColors.primary.withValues(alpha: 0.35),
                AppColors.primary.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});

  final double progress;

  static const _stroke = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final circle = (Offset.zero & size).deflate(_stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = AppColors.primary.withValues(alpha: 0.12);
    final sweep = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primary;

    canvas.drawArc(circle, 0, math.pi * 2, false, track);
    canvas.drawArc(circle, -math.pi / 2, math.pi * 2 * progress, false, sweep);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _PhotoIndicator extends StatelessWidget {
  const _PhotoIndicator({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: index == active ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: index == active
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.22),
            ),
          ),
      ],
    );
  }
}
