import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

const _colorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: AppColors.primary,
  onPrimary: Colors.white,
  primaryContainer: AppColors.primaryLight,
  onPrimaryContainer: Colors.white,
  secondary: AppColors.primaryLight,
  onSecondary: Colors.white,
  // El acento es demasiado claro para texto pequeño: solo como fondo de chips y distintivos.
  tertiary: AppColors.accent,
  onTertiary: AppColors.textPrimary,
  error: AppColors.error,
  onError: Colors.white,
  surface: AppColors.surface,
  onSurface: AppColors.textPrimary,
  onSurfaceVariant: AppColors.textSecondary,
  outline: AppColors.border,
);

ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: _colorScheme,
    scaffoldBackgroundColor: AppColors.background,
  );
}
