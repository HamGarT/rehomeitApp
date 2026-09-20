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

const _radius = 14.0;

OutlineInputBorder _inputBorder(Color color, double width) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(_radius),
    borderSide: BorderSide(color: color, width: width),
  );
}

ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: _colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarThemeData(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primaryLight,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 32),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: _inputBorder(AppColors.border, 1),
      enabledBorder: _inputBorder(AppColors.border, 1),
      focusedBorder: _inputBorder(AppColors.primary, 2),
      hintStyle: const TextStyle(color: AppColors.textSecondary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      labelStyle: const TextStyle(color: AppColors.textPrimary),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      showCheckmark: false,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
