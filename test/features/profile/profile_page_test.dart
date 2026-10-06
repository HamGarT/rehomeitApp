import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rehomeitapp/app/theme.dart';
import 'package:rehomeitapp/core/storage/local_preferences.dart';
import 'package:rehomeitapp/core/constants/item_weights.dart';
import 'package:rehomeitapp/features/auth/domain/app_user.dart';
import 'package:rehomeitapp/features/auth/presentation/auth_controller.dart';
import 'package:rehomeitapp/features/explore/domain/public_profile.dart';
import 'package:rehomeitapp/features/explore/presentation/explore_controller.dart';
import 'package:rehomeitapp/features/profile/domain/profile_summary.dart';
import 'package:rehomeitapp/features/profile/presentation/profile_controller.dart';
import 'package:rehomeitapp/features/profile/presentation/profile_page.dart';
import 'package:rehomeitapp/features/profile/presentation/public_profile_page.dart';
import 'package:rehomeitapp/shared/domain/publication.dart';

const _uid = 'userone';

/// Preferencia falsa para el harness.
///
/// El harness resuelve `sharedPreferencesProvider` de forma síncrona porque el
/// `DarkModeNotifier` lee el valor en `build`. Un `Fake` con la interfaz
/// completa de `SharedPreferences` sería mucho código para un `getBool` que
/// siempre devuelve `false`, así que se implementa solo con lo que se usa.
///
/// Los métodos no implementados lanzan: si el notifier empieza a escribir, el
/// test falla con un mensaje claro en vez de guardar en el vacío.
class _FakePreferences implements SharedPreferences {
  @override
  bool? getBool(String key) => false;

  @override
  Future<bool> setBool(String key, bool value) => throw UnimplementedError();

  @override
  int? getInt(String key) => throw UnimplementedError();

  @override
  Future<bool> setInt(String key, int value) => throw UnimplementedError();

  @override
  String? getString(String key) => throw UnimplementedError();

  @override
  Future<bool> setString(String key, String value) =>
      throw UnimplementedError();

  @override
  double? getDouble(String key) => throw UnimplementedError();

  @override
  Future<bool> setDouble(String key, double value) =>
      throw UnimplementedError();

  @override
  List<String>? getStringList(String key) => throw UnimplementedError();

  @override
  Future<bool> setStringList(String key, List<String> value) =>
      throw UnimplementedError();

  // Los `*Fallback` que aparecen aquí ya no existen en la interfaz de esta
  // versión de `shared_preferences`, así que se dejan fuera a propósito en vez
  // de implementarlos.

  @override
  Future<bool> clear() => throw UnimplementedError();

  @override
  Future<bool> commit() async => true;

  @override
  bool containsKey(String key) => false;

  @override
  Object? get(String key) => null;

  @override
  Set<String> getKeys() => const {};

  @override
  Future<bool> remove(String key) => throw UnimplementedError();

  @override
  Future<void> reload() async {}
}

Publication _pub({
  String id = 'a',
  String authorId = _uid,
  PublicationStatus status = PublicationStatus.published,
  String category = 'Juguetes',
  DateTime? deliveredAt,
}) {
  return Publication(
    id: id,
    authorId: authorId,
    title: 'Juguete $id',
    category: category,
    condition: 'Nuevo',
    description: 'Descripción de prueba.',
    details: const [],
    district: 'Cajamarca',
    mode: PublicationMode.donation,
    status: status,
    images: const [],
    publishedAt: DateTime.utc(2026, 1, 1, 12),
    // Una entrega sin `deliveredAt` no tiene hito de entrega, que es justo el caso
    // que distingue "registrada" de "confirmada" en `ProfileSummary`.
    statusDates: deliveredAt == null
        ? const {}
        : {PublicationStatus.delivered: deliveredAt},
  );
}

/// Monta el perfil propio con todo resuelto. Sin esto cada provider tocaría
/// Firestore de verdad. El `SharedPreferences` hace falta porque el interruptor
/// de modo oscuro lee de ahí al construirse.
Widget _hostOwn(
  List<Publication> items, {
  String name = 'Ana Torres',
  String district = 'Cajamarca',
}) {
  return ProviderScope(
    overrides: [
      // El interruptor de modo oscuro lee las preferencias locales al
      // construirse. Sin este override la pantalla propia revienta antes de
      // pintar nada.
      sharedPreferencesProvider.overrideWithValue(_FakePreferences()),
      profilePublicationsProvider.overrideWith(
        (ref, userId) => Stream.value(items),
      ),
      publicProfileProvider.overrideWith(
        (ref, userId) => Stream.value(
          PublicProfile(
            id: userId,
            shortName: 'Ana T.',
            district: district,
            joinedAt: DateTime.utc(2026, 1, 15),
          ),
        ),
      ),
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          AppUser(uid: _uid, email: 'ana@correo.test', displayName: name),
        ),
      ),
    ],
    child: MaterialApp(
      theme: buildAppTheme(brightness: Brightness.light),
      home: const Scaffold(body: ProfilePage()),
    ),
  );
}

Widget _hostPublic(List<Publication> items, {String shortName = 'Luis Q.'}) {
  return ProviderScope(
    overrides: [
      profilePublicationsProvider.overrideWith(
        (ref, userId) => Stream.value(items),
      ),
      publicProfileProvider.overrideWith(
        (ref, userId) => Stream.value(
          PublicProfile(
            id: userId,
            shortName: shortName,
            district: 'La Encañada',
            joinedAt: DateTime.utc(2025, 3, 1),
          ),
        ),
      ),
      authStateProvider.overrideWith(
        (ref) => Stream.value(const AppUser(uid: _uid)),
      ),
    ],
    child: MaterialApp(
      theme: buildAppTheme(brightness: Brightness.light),
      home: const PublicProfilePage(userId: 'otra'),
    ),
  );
}

void main() {
  group('ProfileSummary', () {
    test('las entregas por confirmar cuentan como registradas, no como '
        'confirmadas', () {
      final summary = ProfileSummary.fromPublications([
        _pub(id: 'a', status: PublicationStatus.published),
        _pub(
          id: 'b',
          status: PublicationStatus.delivered,
          deliveredAt: DateTime.now().toUtc().subtract(
            const Duration(hours: 2),
          ),
        ),
        _pub(id: 'c', status: PublicationStatus.confirmed),
      ]);

      expect(summary.publishedCount, 3);
      // "Entrega registrada" y "entrega confirmada" son cosas distintas
      // (HU20, criterio 6).
      expect(summary.deliveriesRegistered, 2);
      expect(summary.deliveriesConfirmed, 1);
      expect(summary.pendingConfirmation, 1);
    });

    test('anuladas y retiradas no cuentan como publicaciones', () {
      final summary = ProfileSummary.fromPublications([
        _pub(id: 'a', status: PublicationStatus.published),
        _pub(id: 'b', status: PublicationStatus.cancelled),
        _pub(id: 'c', status: PublicationStatus.removed),
      ]);

      expect(summary.publishedCount, 1);
    });

    test('solo el ciclo cerrado acumula residuos evitados', () {
      // HU18, criterio 5: las publicadas, comprometidas o anuladas no suman.
      final summary = ProfileSummary.fromPublications([
        _pub(id: 'a', status: PublicationStatus.published, category: 'Muebles'),
        _pub(id: 'b', status: PublicationStatus.committed, category: 'Muebles'),
        _pub(id: 'c', status: PublicationStatus.cancelled, category: 'Muebles'),
        _pub(id: 'd', status: PublicationStatus.confirmed, category: 'Muebles'),
      ]);

      // Solo la confirmada: un mueble pesa 30 kg según la tabla.
      expect(summary.avoidedKg, ItemWeights.weightFor('Muebles'));
      expect(summary.avoidedKg, 30);
    });

    test('el perfil público oculta anuladas y retiradas', () {
      final visible = ProfileSummary.publicPublications([
        _pub(id: 'a', status: PublicationStatus.published),
        _pub(id: 'b', status: PublicationStatus.cancelled),
        _pub(id: 'c', status: PublicationStatus.removed),
        _pub(id: 'd', status: PublicationStatus.confirmed),
      ]);

      // HU20, criterio 17.
      expect(visible.map((p) => p.id), ['a', 'd']);
    });

    test('una categoría desconocida pesa con el valor de reserva', () {
      expect(
        ItemWeights.weightFor('Categoría inventada'),
        ItemWeights.fallbackKg,
      );
    });
  });

  group('perfil propio', () {
    testWidgets('muestra nombre completo, distrito y fecha de ingreso', (
      tester,
    ) async {
      await tester.pumpWidget(_hostOwn([]));
      await tester.pumpAndSettle();

      expect(find.text('Ana Torres'), findsOneWidget);
      expect(find.text('Cajamarca'), findsOneWidget);
      expect(find.text('Se unió en enero de 2026'), findsOneWidget);
      // El correo solo aparece en el perfil propio (criterio 10).
      expect(find.text('ana@correo.test'), findsOneWidget);
    });

    testWidgets('sin publicaciones muestra el estado vacío', (tester) async {
      await tester.pumpWidget(_hostOwn([]));
      await tester.pumpAndSettle();

      expect(find.text('Todavía no has publicado nada'), findsOneWidget);
      // Un perfil sin publicaciones tiene un contador en cero, no en blanco.
      expect(
        find.bySemanticsLabel('Publicaciones realizadas: 0'),
        findsOneWidget,
      );
    });

    // Cada estado en su propio `testWidgets`. Montar dos veces el mismo árbol dentro
    // de un solo test reutiliza el `ProviderScope` de la primera vez, así que el
    // `overrideWith` del segundo montaje no llega a takerser efecto y la fila
    // seguiría mostrando el estado anterior.
    for (final (status, label) in <(PublicationStatus, String)>[
      (PublicationStatus.confirmed, 'Confirmada'),
      (PublicationStatus.published, 'Publicada'),
      // El historial propio sí muestra lo que se retiró: el perfil público es el
      // único que las esconde.
      (PublicationStatus.removed, 'Retirada'),
    ]) {
      testWidgets(
        'el perfil propio lista una publicación ${label.toLowerCase()}',
        (tester) async {
          await tester.pumpWidget(_hostOwn([_pub(id: 'a', status: status)]));
          await tester.pumpAndSettle();

          // Con una sola publicación la fila cabe en la ventana del test, así que
          // no hace falta desplazarse a ella.
          expect(find.text('Juguete a'), findsOneWidget);
          expect(find.text(label), findsOneWidget);
        },
      );
    }

    testWidgets('el acumulado de residuos aparece junto al aviso de que es '
        'una estimación', (tester) async {
      await tester.pumpWidget(
        _hostOwn([
          _pub(
            id: 'a',
            status: PublicationStatus.confirmed,
            category: 'Muebles',
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('30 kg estimados'), findsOneWidget);
      // Criterio 6 de HU18: el aviso no puede quedar en un tooltip.
      expect(find.textContaining('no una medida'), findsOneWidget);
    });

    testWidgets('sin operaciones cerradas el indicador lo dice', (
      tester,
    ) async {
      await tester.pumpWidget(_hostOwn([_pub(id: 'a')]));
      await tester.pumpAndSettle();

      expect(find.text('Aún no hay operaciones cerradas'), findsOneWidget);
    });
  });

  group('perfil público', () {
    testWidgets('muestra el nombre corto, nunca el completo ni el correo', (
      tester,
    ) async {
      await tester.pumpWidget(_hostPublic([]));
      await tester.pumpAndSettle();

      // HU20, criterio 13: ante terceros solo el nombre abreviado.
      expect(find.text('Luis Q.'), findsOneWidget);
      // El apellido completo no aparece por ninguna parte de la pantalla.
      expect(find.textContaining('Quintana'), findsNothing);
      // Criterio 16: ni correo ni teléfono.
      expect(find.textContaining('@'), findsNothing);
      expect(find.textContaining('9'), findsNothing);
    });

    testWidgets('solo enseña los dos contadores del criterio 18', (
      tester,
    ) async {
      await tester.pumpWidget(_hostPublic([]));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Publicaciones realizadas: 0'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Entregas confirmadas: 0'), findsOneWidget);
      // "Entregas registradas" es un dato de seguimiento, no de cara al público.
      expect(
        find.bySemanticsLabel(RegExp('Entregas registradas')),
        findsNothing,
      );
    });

    testWidgets('no lista anuladas ni retiradas', (tester) async {
      await tester.pumpWidget(
        _hostPublic([
          _pub(id: 'a', authorId: 'otra', status: PublicationStatus.published),
          _pub(id: 'b', authorId: 'otra', status: PublicationStatus.removed),
          _pub(id: 'c', authorId: 'otra', status: PublicationStatus.cancelled),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(RegExp('Juguete a')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Juguete b')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Juguete c')), findsNothing);
    });

    testWidgets('no ofrece iniciar conversación', (tester) async {
      await tester.pumpWidget(
        _hostPublic([
          _pub(id: 'a', authorId: 'otra', status: PublicationStatus.published),
        ]),
      );
      await tester.pumpAndSettle();

      // HU20, criterio 20: se abre desde el detalle de la publicación.
      expect(find.textContaining('Enviar mensaje'), findsNothing);
      expect(find.textContaining('Conversar'), findsNothing);
    });

    testWidgets('sin nada disponible muestra el estado vacío', (tester) async {
      await tester.pumpWidget(_hostPublic([]));
      await tester.pumpAndSettle();

      expect(find.text('Nada por aquí'), findsOneWidget);
    });
  });
}
