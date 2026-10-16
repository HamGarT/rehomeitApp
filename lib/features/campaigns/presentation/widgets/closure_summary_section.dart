import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/campaign.dart';

/// Resumen de cierre de una campaña (HU17). Se arma al consultar desde los
/// contadores de la campaña, así que lo ve cualquier persona (HU17-7) y no
/// cambia después del cierre (HU17-11).
class ClosureSummarySection extends StatelessWidget {
  const ClosureSummarySection({
    super.key,
    required this.summary,
    this.onEditDestination,
  });

  final CampaignSummary summary;

  /// Solo la organización dueña lo recibe (HU17-6); para el resto es nulo y
  /// no hay botón.
  final VoidCallback? onEditDestination;

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Resumen de cierre', style: textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Solo cuenta lo que la organización confirmó haber recibido.',
          style: TextStyle(color: palette.textSecondary),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final need in summary.needs) _NeedRow(need: need),
                const Divider(height: 22),
                _TotalsRow(summary: summary),
                const SizedBox(height: 6),
                _DetailRow(
                  icon: Icons.place_outlined,
                  text: 'Distrito atendido: ${summary.district}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Destino de lo recibido', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        if (summary.hasDestinationNote)
          Text(summary.destinationNote!, key: const Key('destination-note'))
        else
          Text(
            'La organización aún no describió el destino de lo recibido.',
            key: const Key('destination-note-missing'),
            style: TextStyle(color: palette.textSecondary),
          ),
        if (onEditDestination case final onEdit?) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('edit-destination-button'),
            onPressed: onEdit,
            icon: const Icon(Icons.edit_note_outlined),
            label: Text(
              summary.hasDestinationNote
                  ? 'Editar destino'
                  : 'Describir el destino',
            ),
          ),
        ],
      ],
    );
  }
}

class _NeedRow extends StatelessWidget {
  const _NeedRow({required this.need});

  final CampaignNeedSummary need;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(need.name)),
        Text(
          '${need.contributedQuantity} de ${need.requiredQuantity}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (need.isCovered) ...[
          const SizedBox(width: 8),
          const Icon(
            Icons.check_circle_outline,
            size: 18,
            color: AppColors.success,
          ),
        ],
      ],
    ),
  );
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({required this.summary});

  final CampaignSummary summary;

  @override
  Widget build(BuildContext context) {
    final contributions = summary.confirmedContributions;
    final people = summary.contributorsCount;
    final label =
        '${contributions == 1 ? '1 aporte confirmado' : '$contributions aportes confirmados'}'
        ' de ${people == 1 ? '1 persona' : '$people personas'}';
    return _DetailRow(icon: Icons.volunteer_activism_outlined, text: label);
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: context.appColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
