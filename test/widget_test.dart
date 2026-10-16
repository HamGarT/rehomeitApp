import 'dart:io';

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
import 'package:rehomeitapp/features/publishing/domain/publish_draft.dart';
import 'package:rehomeitapp/features/publishing/presentation/photos_step.dart';
import 'package:rehomeitapp/features/publishing/presentation/publish_draft_notifier.dart';

late SharedPreferences _preferences;

ProviderScope _buildApp({
  AppUser? user,
  PublishDraftNotifier Function()? draft,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(_preferences),
      authStateProvider.overrideWith((ref) => Stream<AppUser?>.value(user)),
      if (draft != null) publishDraftProvider.overrideWith(draft),
    ],
    child: const RehomeitApp(),
  );
}

/// Borrador que ya tiene una fotografía, como queda tras una confirmación
/// fallida por falta de red (HU03-19). La ruta no necesita existir: el shell
/// solo mira si hay fotos.
class _DraftWithPhotoNotifier extends PublishDraftNotifier {
  @override
  PublishDraft build() => PublishDraft(photos: [File('borrador.jpg')]);
}

Future<void> _enterHome(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
  await tester.pumpAndSettle();
  await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Empecemos'));
  await tester.pumpAndSettle();
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
    // La pestaña de inicio es el feed, con el buscador tras la lupa de la
    // cabecera y los filtros en una fila de chips.
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

  testWidgets('sin borrador, Publicar abre el paso de fotografías', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        user: const AppUser(uid: 'uid-1', email: 'a@b.com'),
      ),
    );
    await _enterHome(tester);

    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();

    expect(find.byType(PhotosStep), findsOneWidget);
    expect(find.text('Tienes una publicación sin confirmar'), findsNothing);
  });

  testWidgets('con un borrador, Publicar pregunta antes de descartarlo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        user: const AppUser(uid: 'uid-1', email: 'a@b.com'),
        draft: _DraftWithPhotoNotifier.new,
      ),
    );
    await _enterHome(tester);

    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();
    expect(find.text('Tienes una publicación sin confirmar'), findsOneWidget);

    // Cerrar sin elegir conserva el borrador (HU03-19).
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RehomeitApp)),
    );
    expect(container.read(publishDraftProvider).photos, hasLength(1));
    expect(find.byType(PhotosStep), findsNothing);

    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empezar de nuevo'));
    await tester.pumpAndSettle();
    expect(container.read(publishDraftProvider).photos, isEmpty);
    expect(find.byType(PhotosStep), findsOneWidget);
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
