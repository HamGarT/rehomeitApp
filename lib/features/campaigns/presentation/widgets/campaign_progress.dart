import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/campaign.dart';

class CampaignProgress extends StatelessWidget {
  const CampaignProgress({super.key, required this.campaign});

  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final percent = campaign.progressPercent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${campaign.totalContributed} de ${campaign.totalRequired} aportes',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: context.appColors.textSecondary),
              ),
            ),
            Text(
              '${percent.toStringAsFixed(percent == percent.roundToDouble() ? 0 : 1)} %',
              key: const Key('campaign-progress-label'),
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 7),
        LinearProgressIndicator(
          key: const Key('campaign-progress-indicator'),
          value: campaign.progressForIndicator,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
          backgroundColor: context.appColors.border,
          color: AppColors.success,
        ),
      ],
    );
  }
}
