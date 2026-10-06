import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rehomeitapp/app/app.dart';
import 'package:rehomeitapp/app/theme.dart';
import 'package:rehomeitapp/core/constants/app_colors.dart';
import 'package:rehomeitapp/core/storage/local_preferences.dart';
import 'package:rehomeitapp/features/auth/domain/app_user.dart';
import 'package:rehomeitapp/features/auth/presentation/auth_controller.dart';
import 'package:rehomeitapp/features/profile/presentation/profile_page.dart';

late SharedPreferences _preferences;

ProviderScope _buildApp({AppUser? user}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(_preferences),
      authStateProvider.overrideWith((ref) => Stream<AppUser?>.value(user)),
    ],
    child: const RehomeitApp(),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _preferences = await SharedPreferences.getInstance();
  });

  testWidgets('shows onboarding on launch', (WidgetTester tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    expect(
      find.text('No dejes que se desperdicien las cosas buenas'),
      findsOneWidget,
    );
  });

  testWidgets('shows login after completing onboarding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empecemos'));
    await tester.pumpAndSettle();
    expect(find.text('¡Hola de nuevo!'), findsOneWidget);
  });

  testWidgets('authenticated users skip login and go straight home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        user: const AppUser(uid: 'uid-1', email: 'a@b.com'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empecemos'));
    await tester.pumpAndSettle();
    // La pestaña de inicio es el feed; Explorar ya no está en la barra, se
    // llega desde el icono de búsqueda de la cabecera.
    expect(find.text('Rehomeit'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('¡Hola de nuevo!'), findsNothing);
  });

  testWidgets('el modo oscuro se puede cambiar desde Perfil y se guarda', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        user: const AppUser(uid: 'uid-1', email: 'a@b.com'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empecemos'));
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.light);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Mi perfil'), findsOneWidget);

    final switchFinder = find.byType(Switch);
    // El interruptor queda por debajo del pliegue: la cabecera, los contadores
    // y el indicador de residuos van por delante. El sliver es perezoso, así
    // que sin desplazarse el interruptor ni siquiera está construido.
    await tester.scrollUntilVisible(switchFinder, 200);
    expect(switchFinder, findsOneWidget);
    expect(tester.widget<Switch>(switchFinder).value, isFalse);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(tester.widget<Switch>(switchFinder).value, isTrue);
    expect(_preferences.getBool('dark_mode'), isTrue);

    // El fondo del perfil estaba escrito como token fijo; en oscuro debe
    // resolver a la paleta oscura, no quedarse en el blanco de marca.
    //
    // `ProfilePage` no trae `Scaffold` propio: lo aporta el shell, igual que
    // hace con el feed. El `Scaffold` del shell toma su fondo del tema, así que
    // basta con que ese fondo sea el oscuro.
    final scaffold = tester.widget<Scaffold>(
      find.ancestor(
        of: find.byType(ProfilePage),
        matching: find.byType(Scaffold),
      ),
    );
    // `backgroundColor` en nulo significa "toma el del tema", así que se
    // resuelve igual que lo haría la pantalla.
    expect(
      scaffold.backgroundColor ??
          Theme.of(tester.element(find.byType(ProfilePage)))
              .scaffoldBackgroundColor,
      AppColorsDark.background,
    );
  });

  testWidgets('el color de acción se invierte junto con el tema', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        user: const AppUser(uid: 'uid-1', email: 'a@b.com'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empecemos'));
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final light = materialApp.theme!.extension<AppPalette>()!;
    final dark = materialApp.darkTheme!.extension<AppPalette>()!;

    // El marrón se sustituye por negro en claro y gris casi blanco en oscuro,
    // para que los iconos y enlaces no se pierdan contra el fondo.
    expect(light.primary, AppColors.primary);
    expect(dark.primary, AppColorsDark.primary);
    expect(light.primary, isNot(dark.primary));

    // El contenido de un círculo o botón de `primary` tiene quecontrastar:
    // blanco sobre negro en claro, negro sobre gris claro en oscuro. Sin esta
    // inversión el avatar y los botones saldrían ilegibles en modo oscuro.
    expect(materialApp.theme!.colorScheme.onPrimary, light.onPrimary);
    expect(materialApp.darkTheme!.colorScheme.onPrimary, dark.onPrimary);
    expect(
      light.onPrimary.computeLuminance(),
      greaterThan(light.primary.computeLuminance()),
    );
    expect(
      dark.onPrimary.computeLuminance(),
      lessThan(dark.primary.computeLuminance()),
    );
  });
}
