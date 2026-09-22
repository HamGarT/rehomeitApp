import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import 'onboarding_notifier.dart';
import 'widgets/onboarding_illustrations.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  static const _slideCount = 3;

  static const _backgroundColors = [
    Color(0xFFF3CA20),
    Color(0xFFF3CA20),
    Color(0xFFF3CA20),
  ];

  static const _titles = [
    'No dejes que se desperdicien las cosas buenas',
    'Quizá alguien lo necesite',
    "Alegra el día a alguien",
  ];

  static const _descriptions = [
    'Eso que ya no usas podría ser justo lo que otra persona necesita.',
    'Publica cosas que ya no usas y encuentra a alguien que pueda darles un nuevo hogar.',
    'Descubre cosas útiles cerca de ti y da a tus pertenencias sin usar una segunda oportunidad.',
  ];

  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    ref.read(onboardingCompletedProvider.notifier).complete();
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slideCount - 1;

    return Scaffold(
      backgroundColor: _backgroundColors[_index],
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 6, right: 12),
                child: Visibility(
                  visible: !isLast,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TextButton(
                    onPressed: _complete,
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Skip'),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                physics: const BouncingScrollPhysics(),
                itemCount: _slideCount,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) => _OnboardingSlide(
                  title: _titles[index],
                  description: _descriptions[index],
                  illustrationIndex: index,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _Dots(active: _index, count: _slideCount),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 4, 28, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isLast ? _complete : _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                  ),
                  child: Text(isLast ? "Empecemos!!" : 'Siguiente'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({
    required this.title,
    required this.description,
    required this.illustrationIndex,
  });

  final String title;
  final String description;
  final int illustrationIndex;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageHeight = constraints.maxHeight * 0.5;
          final textAreaHeight = constraints.maxHeight - imageHeight - 16;

          final titleStyle = texts.titleLarge?.copyWith(
            fontSize: 50,
            fontWeight: FontWeight.w400,
            height: 1.2,
            color: Colors.black,
            fontFamily: 'FreckleFace',
          );
          final descriptionStyle = texts.bodyLarge?.copyWith(
            fontSize: 19,
            color: Colors.black,
            fontFamily: 'HostGrotesk',
            height: 1.45,
          );

          final titlePainter = TextPainter(
            text: TextSpan(text: title, style: titleStyle),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: constraints.maxWidth);
          final descriptionPainter = TextPainter(
            text: TextSpan(text: description, style: descriptionStyle),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: constraints.maxWidth);

          final neededHeight =
              titlePainter.height + 12 + descriptionPainter.height;
          final scale = (textAreaHeight / neededHeight).clamp(0.35, 1.0);

          return Column(
            children: [
              SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: OnboardingIllustration(index: illustrationIndex),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: titleStyle?.copyWith(fontSize: 50 * scale),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          description,
                          textAlign: TextAlign.center,
                          style: descriptionStyle?.copyWith(
                            fontSize: 19 * scale,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          );
        },
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.active, required this.count});

  final int active;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == active ? Colors.white : Colors.white54,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
