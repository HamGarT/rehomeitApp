import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

enum AppSnackBarKind { info, success, error }

const _fallbackMessage = 'Algo salió mal. Inténtalo de nuevo.';

/// Aviso breve al pie. Forma, posición y tipografía salen de `snackBarTheme`;
/// aquí solo se decide el color según el resultado.
void showAppSnackBar(
  BuildContext context,
  String message, {
  AppSnackBarKind kind = AppSnackBarKind.info,
}) {
  final background = switch (kind) {
    AppSnackBarKind.info => null,
    AppSnackBarKind.success => AppColors.success,
    AppSnackBarKind.error => AppColors.error,
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message.isEmpty ? _fallbackMessage : message),
        backgroundColor: background,
      ),
    );
}
