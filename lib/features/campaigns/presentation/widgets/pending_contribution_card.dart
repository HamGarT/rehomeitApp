import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/contribution.dart';

class PendingContributionCard extends StatelessWidget {
  const PendingContributionCard({
    super.key,
    required this.contribution,
    required this.onConfirm,
    required this.onReject,
    this.showCampaign = false,
  });

  final Contribution contribution;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  final bool showCampaign;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${contribution.quantity} × ${contribution.needName}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (showCampaign && contribution.campaignTitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              contribution.campaignTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.appColors.textSecondary),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            'Aporta ${contribution.contributorName}',
            style: TextStyle(color: context.appColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onReject,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  // El tema global fija una altura de 52 y un ancho mínimo
                  // infinito (pensado para botones a lo ancho). Dentro de un
                  // Row hay que acotar el ancho o la tarjeta revienta.
                  minimumSize: const Size(0, 44),
                ),
                child: const Text('Rechazar'),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: onConfirm,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                ),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
