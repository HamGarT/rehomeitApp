import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/item_weights.dart';

/// Cifra de residuos evitados lista para mostrar. Por debajo de un kilogramo
/// la cifra no dice nada: "0 kg" o "0,3 kg" se leen como un error de cálculo.
String impactAmountLabel(double kilograms) {
  if (kilograms <= 0) return 'Aún no hay operaciones cerradas';
  if (kilograms < 1) return 'Menos de 1 kg estimados';
  final rounded = kilograms.round();
  return rounded == 1 ? '1 kg estimado' : '$rounded kg estimados';
}

/// Aviso que acompaña siempre a la cifra (HU18-6). Escrito a la vista y no en
/// un tooltip, para que nadie lea la estimación como una medición del bien.
const impactDisclaimer =
    'Es una estimación según el peso promedio de la categoría, no una medida '
    'del bien.';

/// Estimación de residuos evitados por una operación cerrada (HU18-3). La
/// comparten el recorrido y el detalle de la entrega (D10).
class ImpactNote extends StatelessWidget {
  const ImpactNote({super.key, required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.eco_outlined, size: 22, color: AppColors.success),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Residuos evitados: '
                  '${impactAmountLabel(ItemWeights.weightFor(category))}',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  impactDisclaimer,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: palette.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
