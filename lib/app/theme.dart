import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

/// Los tokens que cambian con el brillo. Se resuelven desde el tema en vez de
/// leerse de [AppColors] directamente, porque una constante estática no puede
/// saber si la pantalla está en claro o en oscuro.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.chipFill,
    required this.imageScrim,
    required this.onImageScrim,
    required this.primary,
    required this.onPrimary,
  });

  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  /// Relleno del chip sin seleccionar.
  final Color chipFill;

  /// Color del velo degradado sobre las fotos.
  final Color imageScrim;

  /// Texto que se apoya sobre [imageScrim].
  final Color onImageScrim;

  /// Acción e interacción. Negro en claro, gris casi blanco en oscuro, para
  /// que los botones y enlaces nunca se pierdan contra el fondo.
  final Color primary;

  /// Contenido dentro de un círculo o botón de [primary].
  final Color onPrimary;

  static const light = AppPalette(
    background: AppColors.background,
    surface: AppColors.surface,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    border: AppColors.border,
    chipFill: Color(0xE2E5E9ED),
    imageScrim: AppColors.imageScrim,
    onImageScrim: AppColors.onImageScrim,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
  );

  static const dark = AppPalette(
    background: AppColorsDark.background,
    surface: AppColorsDark.surface,
    textPrimary: AppColorsDark.textPrimary,
    textSecondary: AppColorsDark.textSecondary,
    border: AppColorsDark.border,
    chipFill: AppColorsDark.chipFill,
    imageScrim: AppColorsDark.imageScrim,
    onImageScrim: AppColorsDark.onImageScrim,
    primary: AppColorsDark.primary,
    onPrimary: AppColorsDark.onPrimary,
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? chipFill,
    Color? imageScrim,
    Color? onImageScrim,
    Color? primary,
    Color? onPrimary,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      chipFill: chipFill ?? this.chipFill,
      imageScrim: imageScrim ?? this.imageScrim,
      onImageScrim: onImageScrim ?? this.onImageScrim,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
    );
  }

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      chipFill: Color.lerp(chipFill, other.chipFill, t)!,
      imageScrim: Color.lerp(imageScrim, other.imageScrim, t)!,
      onImageScrim: Color.lerp(onImageScrim, other.onImageScrim, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
    );
  }
}

/// Atajo de lectura: `context.appColors.textPrimary`.
extension AppPaletteContext on BuildContext {
  AppPalette get appColors => Theme.of(this).extension<AppPalette>()!;
}

ColorScheme _colorSchemeFor(Brightness brightness, AppPalette palette) {
  final isDark = brightness == Brightness.dark;
  return ColorScheme(
    brightness: brightness,
    // Negro en claro, gris casi blanco en oscuro. El texto encima se invierte
    // para no quedar blanco sobre un botón claro.
    primary: palette.primary,
    onPrimary: palette.onPrimary,
    primaryContainer: isDark ? AppColorsDark.surface : AppColors.primaryLight,
    onPrimaryContainer: isDark ? AppColorsDark.textPrimary : Colors.black,
    // El verde marca donación y éxito, no la marca.
    secondary: AppColors.success,
    onSecondary: Colors.white,
    // El amarillo es demasiado claro para texto: solo como fondo de chips,
    // distintivos y superficies de marca.
    tertiary: AppColors.accent,
    onTertiary: AppColors.textPrimary,
    error: isDark ? AppColorsDark.error : AppColors.error,
    onError: isDark ? AppColorsDark.background : Colors.white,
    surface: palette.surface,
    onSurface: palette.textPrimary,
    onSurfaceVariant: palette.textSecondary,
    outline: palette.border,
  );
}

const _radius = 18.0;
const _fontFamily = 'HostGrotesk';

// Escala compacta para formularios. Los niveles ya en 12 pt no bajan: es el piso de lectura.
const _textTheme = TextTheme(
  titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
  titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  bodyLarge: TextStyle(fontSize: 15),
  bodyMedium: TextStyle(fontSize: 13),
  labelLarge: TextStyle(fontSize: 13),
);

OutlineInputBorder _inputBorder(Color color, double width) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(_radius),
    borderSide: BorderSide(color: color, width: width),
  );
}

/// Una sola transición para toda la app: fundido con un leve ascenso.
/// Reemplaza el deslizamiento lateral de Android, que se siente mecánico.
class _WarmPageTransitionsBuilder extends PageTransitionsBuilder {
  const _WarmPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  final palette = isDark ? AppPalette.dark : AppPalette.light;
  final colorScheme = _colorSchemeFor(brightness, palette);

  return ThemeData(
    brightness: brightness,
    colorScheme: colorScheme,
    extensions: [palette],
    fontFamily: _fontFamily,
    textTheme: _textTheme,
    scaffoldBackgroundColor: palette.background,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _WarmPageTransitionsBuilder(),
        TargetPlatform.iOS: _WarmPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: palette.background,
      foregroundColor: palette.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: palette.textPrimary,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.accent,
      elevation: 0,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          // El indicador es el amarillo de marca, brillante en los dos modos:
          // el icono seleccionado va oscuro encima, no marrón.
          color: states.contains(WidgetState.selected)
              ? AppColors.onAccent
              : palette.textSecondary,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          // El peso marca la selección, no el color: la etiqueta vive sobre el
          // fondo de la barra, no sobre el indicador amarillo, así que
          // `onAccent` (casi negro) la volvía ilegible en modo oscuro.
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: palette.textSecondary,
        ),
      ),
    ),
    dividerTheme: DividerThemeData(color: palette.border, space: 32),
    cardTheme: CardThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius),
        side: BorderSide(color: palette.border),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: palette.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: _inputBorder(palette.border, 1),
      enabledBorder: _inputBorder(palette.border, 1),
      focusedBorder: _inputBorder(colorScheme.primary, 2),
      hintStyle: TextStyle(color: palette.textSecondary),
      labelStyle: TextStyle(color: palette.textSecondary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: colorScheme.primary,
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: palette.surface,
      selectedColor: AppColors.primary,
      side: BorderSide(color: palette.border),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(color: palette.textPrimary),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      showCheckmark: false,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            // La pista activa es `primary`: en claro es negra y el pulgar va
            // blanco; en oscuro es casi blanca y el pulgar tiene que ser negro
            // o desaparece.
            ? (isDark ? Colors.black : Colors.white)
            : palette.surface,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colorScheme.primary
            : palette.border,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colorScheme.primary
            : palette.border,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? AppColorsDark.elevated : palette.textPrimary,
      contentTextStyle: TextStyle(
        fontFamily: _fontFamily,
        color: isDark ? palette.textPrimary : Colors.white,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
    ),
  );
}
