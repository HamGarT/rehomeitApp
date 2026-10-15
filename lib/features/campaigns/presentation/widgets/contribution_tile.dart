import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_format.dart';
import '../../domain/contribution.dart';

class ContributionTile extends StatelessWidget {
  const ContributionTile({
    super.key,
    required this.contribution,
    this.showCampaign = true,
  });

  final Contribution contribution;
  final bool showCampaign;

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${contribution.quantity} × ${contribution.needName}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(status: contribution.status),
            ],
          ),
          if (showCampaign && contribution.campaignTitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              contribution.campaignTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Registrado el ${formatDateTime(contribution.createdAt)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          if (contribution.isRejected &&
              contribution.rejectionReason != null) ...[
            const SizedBox(height: 6),
            Text(
              'Motivo: ${contribution.rejectionReason}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
          if (contribution.hasPendingWrites) ...[
            const SizedBox(height: 6),
            Text(
              'Pendiente de sincronización',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.warning,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ContributionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ContributionStatus.pending => AppColors.warning,
      ContributionStatus.confirmed => AppColors.success,
      ContributionStatus.rejected => AppColors.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
