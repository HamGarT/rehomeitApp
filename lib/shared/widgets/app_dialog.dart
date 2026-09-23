import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'mascot.dart';

/// Diálogo único de la app. Fija la composición que funcionó en el diálogo de
/// detalle: título compacto, subtítulo gris, contenido opcional y acciones en
/// fila de igual ancho. Los usos solo cambian lo que va dentro.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.actions,
    this.subtitle,
    this.header,
    this.content,
  });

  final String title;
  final String? subtitle;

  /// Elemento sobre el título: un icono en círculo o la mascota.
  final Widget? header;
  final Widget? content;

  /// Uno o dos botones; se reparten el ancho en partes iguales.
  final List<Widget> actions;

  static const _actionHeight = 48.0;
  static const _actionPadding = EdgeInsets.symmetric(horizontal: 10);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final texts = theme.textTheme;

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) ...[
              Center(child: header),
              const SizedBox(height: 16),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: texts.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: texts.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
            if (content != null) ...[const SizedBox(height: 22), content!],
            const SizedBox(height: 24),
            // Dos botones comparten un ancho estrecho: relleno corto y letra
            // de 14 para que etiquetas como "Cerrar sesión" entren en una
            // línea, y texto centrado por si alguna llegara a partirse.
            Theme(
              data: theme.copyWith(
                filledButtonTheme: FilledButtonThemeData(
                  style: theme.filledButtonTheme.style?.copyWith(
                    minimumSize: const WidgetStatePropertyAll(
                      Size.fromHeight(_actionHeight),
                    ),
                    padding: const WidgetStatePropertyAll(_actionPadding),
                    textStyle: const WidgetStatePropertyAll(
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: theme.outlinedButtonTheme.style?.copyWith(
                    minimumSize: const WidgetStatePropertyAll(
                      Size.fromHeight(_actionHeight),
                    ),
                    padding: const WidgetStatePropertyAll(_actionPadding),
                    textStyle: const WidgetStatePropertyAll(
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              child: DefaultTextStyle.merge(
                textAlign: TextAlign.center,
                child: Row(
                  spacing: 12,
                  children: [
                    for (final action in actions) Expanded(child: action),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icono en círculo para la cabecera del diálogo.
class AppDialogIcon extends StatelessWidget {
  const AppDialogIcon({
    super.key,
    required this.icon,
    this.color = AppColors.primary,
    this.background = AppColors.accentSoft,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: 32, color: color),
    );
  }
}

/// Confirmación de dos botones. Devuelve `true` si se confirmó.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? subtitle,
  String cancelLabel = 'Cancelar',
  bool destructive = false,
  MascotPose? mascot,
  IconData? icon,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AppDialog(
      title: title,
      subtitle: subtitle,
      header: mascot != null
          ? Mascot(pose: mascot, height: 96)
          : icon != null
          ? AppDialogIcon(
              icon: icon,
              color: destructive ? AppColors.error : AppColors.primary,
            )
          : null,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.error)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
