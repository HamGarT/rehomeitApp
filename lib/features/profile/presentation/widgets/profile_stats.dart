import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/constants/app_colors.dart';

/// Una cifra del perfil con su rótulo.
class ProfileStat {
  const ProfileStat({
    required this.value,
    required this.label,
    required this.semanticLabel,
  });

  final int value;

  /// Rótulo corto del mosaico, que no cabe "entregas registradas" en un tercio
  /// de pantalla sin partirse en dos líneas.
  final String label;

  /// Lo que lee el lector de pantalla: aquí sí va la etiqueta completa.
  final String semanticLabel;
}

/// Tarjeta de actividad: fila de contadores y, opcionalmente, un pie con
/// una cifra más del mismo grupo. Una tarjeta por cifra las haría competir;
/// el pie evita además una segunda superficie para el impacto ambiental, que
/// en la interfaz neutra del perfil se leería como un elemento ajeno.
class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key, required this.stats, this.footer});

  final List<ProfileStat> stats;

  /// Va bajo los contadores, separado por una línea. El perfil público no lo
  /// pasa: solo enseña contadores (HU20, criterio 18).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < stats.length; index++) ...[
                  if (index > 0)
                    // Separador vertical entre cifras. Un `Divider` horizontal
                    // partiría la fila en dos bandas y la dejaría más alta.
                    Container(
                      width: 1,
                      height: 34,
                      margin: const EdgeInsets.only(top: 4),
                      color: palette.border,
                    ),
                  Expanded(
                    child: Semantics(
                      label:
                          '${stats[index].semanticLabel}: ${stats[index].value}',
                      excludeSemantics: true,
                      child: Column(
                        children: [
                          Text(
                            '${stats[index].value}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            stats[index].label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: palette.textSecondary,
                                  height: 1.2,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (footer != null) ...[
            Container(
              height: 1,
              margin: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              color: palette.border,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: footer,
            ),
          ],
        ],
      ),
    );
  }
}

/// Acumulado estimado de residuos evitados (HU18 y HU20, criterio 8). Se
/// pinta como pie de [ProfileStats], sin superficie propia.
///
/// El aviso del criterio 6 va siempre debajo de la cifra y no en un tooltip:
/// "estimación" escrito a la vista es lo que evita que alguien lo lea como una
/// medición del bien que publicó.
class ImpactSummary extends StatelessWidget {
  const ImpactSummary({super.key, required this.kilograms});

  final double kilograms;

  /// El icono va en un círculo porque es el mismo recurso que usa el avatar de
  /// la cabecera; así el verde entra como acento puntual y no como fondo.
  static const _iconCircleSize = 40.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: _iconCircleSize,
          height: _iconCircleSize,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.eco_outlined,
            color: AppColors.success,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Residuos evitados',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _amount(kilograms),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Es una estimación según el peso promedio de la categoría '
                'de cada bien, no una medida de lo que publicaste.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: palette.textSecondary, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Por debajo de un kilogramo la cifra no dice nada: "0 kg" o "0,3 kg" se
  /// leen como un error de cálculo.
  String _amount(double kg) {
    if (kg <= 0) return 'Aún no hay operaciones cerradas';
    if (kg < 1) return 'Menos de 1 kg estimados';
    final rounded = kg.round();
    return rounded == 1 ? '1 kg estimado' : '$rounded kg estimados';
  }
}

/// Rótulo de sección, al estilo del que usa el inicio antes de las
/// publicaciones. Se escribe en gris y en peso medio para que la sección se
/// lean sobre ella y no compita con los datos.
class ProfileSectionHeader extends StatelessWidget {
  const ProfileSectionHeader({super.key, required this.title, this.trailing});

  final String title;

  /// Contador o etiqueta opcional a la derecha, p. ej. cuántas filas hay.
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: context.appColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: context.appColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
