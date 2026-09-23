import 'package:flutter/material.dart';

/// Paleta tomada de los paneles de inicio: amarillo de marca, marrones del
/// cuy y crema cálido para el contenido. El verde queda para donación y éxito.
abstract final class AppColors {
  static const primary = Color(0xFF7A4419);
  static const primaryLight = Color(0xFFB06028);

  /// Amarillo de marca. Fondo de onboarding, acceso, carga y análisis, e
  /// indicador de navegación. Solo lleva texto en [textPrimary].
  static const accent = Color(0xFFF3CA20);

  /// Amarillo suave para fondos de chips, distintivos y avisos.
  static const accentSoft = Color(0xFFFFF0B3);

  /// Crema para pantallas de contenido: cálido sin competir con las fotos.
  static const background = Color(0xFFFFF6D9);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF2A1A0E);
  static const textSecondary = Color(0xFF7A6652);
  static const border = Color(0xFFEADFC4);
  static const success = Color(0xFF2E7D5B);
  static const warning = Color(0xFFD97706);
  static const error = Color(0xFFC0392B);
}
