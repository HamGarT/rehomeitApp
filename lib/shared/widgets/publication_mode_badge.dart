import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../domain/publication.dart';
import 'app_badge.dart';

class PublicationModeBadge extends StatelessWidget {
  const PublicationModeBadge({super.key, required this.mode});

  final PublicationMode mode;

  @override
  Widget build(BuildContext context) {
    final isDonation = mode == PublicationMode.donation;
    return AppBadge(
      label: mode.label,
      background: isDonation ? AppColors.success : AppColors.accent,
      // El relleno es amarillo o verde, brillante en los dos modos: el texto va
      // siempre oscuro encima.
      foreground: AppColors.onAccent,
    );
  }
}
