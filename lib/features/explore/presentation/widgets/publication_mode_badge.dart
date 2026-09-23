import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/domain/publication.dart';

class PublicationModeBadge extends StatelessWidget {
  const PublicationModeBadge({super.key, required this.mode});

  final PublicationMode mode;

  @override
  Widget build(BuildContext context) {
    final isDonation = mode == PublicationMode.donation;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isDonation ? AppColors.success : AppColors.accent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        mode.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isDonation ? AppColors.surface : AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
