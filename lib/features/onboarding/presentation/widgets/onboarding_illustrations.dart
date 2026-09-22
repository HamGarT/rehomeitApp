import 'package:flutter/material.dart';

class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({super.key, required this.index});

  final int index;

  static const _assets = [
    'assets/images/onboarding1.webp',
    'assets/images/onboarding2.webp',
    'assets/images/onboarding3.webp',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Image.asset(_assets[index], fit: BoxFit.contain),
      ),
    );
  }
}
