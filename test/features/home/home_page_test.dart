import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rehomeitapp/app/theme.dart';
import 'package:rehomeitapp/features/auth/domain/app_user.dart';
import 'package:rehomeitapp/features/auth/presentation/auth_controller.dart';
import 'package:rehomeitapp/features/explore/data/explore_repository.dart';
import 'package:rehomeitapp/features/explore/domain/public_profile.dart';
import 'package:rehomeitapp/features/explore/presentation/explore_controller.dart';
import 'package:rehomeitapp/features/home/presentation/home_page.dart';
import 'package:rehomeitapp/shared/domain/publication.dart';

Publication _post(String id, List<String> images) => Publication(
  id: id,
  authorId: 'userone',
  title: 'Hot Wheels $id',
  category: 'Juguetes',
  condition: 'Nuevo',
  description: 'Descripción de prueba.',
  details: const [],
  district: 'Cajamarca',
  mode: PublicationMode.donation,
  status: PublicationStatus.published,
  images: images,
  publishedAt: DateTime.utc(2026, 1, 1, 12),
);

/// Monta el feed con datos ya resueltos: el test no debe depender de
/// Firestore. La sesión queda en el mismo `authorId` que las publicaciones de
/// prueba, para que el cta de "publica algo" se comporte como en la app.
Widget _host(List<Publication> posts, {String authorName = 'Ana T.'}) {
  return ProviderScope(
    overrides: [
      exploreFeedProvider.overrideWithValue(
        AsyncValue.data(ExploreFeed(publications: posts, isFromCache: false)),
      ),
      authStateProvider.overrideWith(
        (ref) => Stream.value(const AppUser(uid: 'userone', email: 'a@b.com')),
      ),
      // La cabecera del post lee el perfil público del autor. Sin este
      // override la tarjeta pediría el documento a Firestore de verdad.
      publicProfileProvider.overrideWith(
        (ref, userId) => Stream.value(
          PublicProfile(
            id: userId,
            shortName: authorName,
            district: 'Cajamarca',
          ),
        ),
      ),
    ],
    child: MaterialApp(
      theme: buildAppTheme(brightness: Brightness.light),
      home: const HomePage(),
    ),
  );
}

void main() {
  const deck = Key('stacked-cards');
  const swipeLeft = Offset(-160, 0);
  const swipeRight = Offset(160, 0);

  testWidgets('el mazo avanza al deslizar a la izquierda y es cíclico', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host([
        _post('a', [
          'https://example.test/1.jpg',
          'https://example.test/2.jpg',
        ]),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(deck), findsOneWidget);
    expect(find.bySemanticsLabel('Foto 1 de 2'), findsOneWidget);

    await tester.drag(find.byKey(deck), swipeLeft);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Foto 2 de 2'), findsOneWidget);

    // Desde la última vuelve a la primera.
    await tester.drag(find.byKey(deck), swipeLeft);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Foto 1 de 2'), findsOneWidget);
  });

  testWidgets('deslizar a la derecha retrocede', (tester) async {
    await tester.pumpWidget(
      _host([
        _post('a', [
          'https://example.test/1.jpg',
          'https://example.test/2.jpg',
          'https://example.test/3.jpg',
        ]),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(deck), swipeLeft);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Foto 2 de 3'), findsOneWidget);

    await tester.drag(find.byKey(deck), swipeRight);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Foto 1 de 3'), findsOneWidget);

    // Desde la primera, retroceder lleva a la última.
    await tester.drag(find.byKey(deck), swipeRight);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Foto 3 de 3'), findsOneWidget);
  });

  testWidgets('un arrastre corto no pasa de foto', (tester) async {
    await tester.pumpWidget(
      _host([
        _post('a', [
          'https://example.test/1.jpg',
          'https://example.test/2.jpg',
        ]),
      ]),
    );
    await tester.pumpAndSettle();

    // Por debajo del umbral se toma como un dedo que se movió al tocar.
    await tester.drag(find.byKey(deck), const Offset(-30, 0));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Foto 1 de 2'), findsOneWidget);
  });

  testWidgets('sin segunda foto no hay indicador ni avance', (tester) async {
    await tester.pumpWidget(
      _host([
        _post('a', ['https://example.test/1.jpg']),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('photo-dots')), findsNothing);

    await tester.drag(find.byKey(deck), swipeLeft);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('photo-dots')), findsNothing);
  });

  testWidgets('la lupa despliega el buscador y la X lo cierra', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host([
        _post('a', ['https://example.test/1.jpg']),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feed-search-field')), findsNothing);

    await tester.tap(find.byKey(const Key('feed-search-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('feed-search-field')), findsOneWidget);

    await tester.tap(find.byKey(const Key('feed-search-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('feed-search-field')), findsNothing);
  });

  testWidgets('los filtros rápidos y el distintivo de modalidad están en el feed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host([
        _post('a', ['https://example.test/1.jpg']),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Todo'), findsOneWidget);
    expect(find.text('Intercambio'), findsOneWidget);
    expect(find.text('Distrito'), findsOneWidget);
    // "Donación" aparece dos veces: el chip del filtro y el distintivo de la
    // publicación de prueba, que es una donación.
    expect(find.text('Donación'), findsNWidgets(2));
  });

  testWidgets('el cta de publicar se oculta al tener publicaciones propias', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host([
        _post('a', ['https://example.test/1.jpg']),
      ]),
    );
    await tester.pumpAndSettle();

    // La publicación pertenece a `userone`, que es quien está autenticado en
    // este harness, así que el banner de "aún no has publicado nada" va fuera.
    expect(find.textContaining('aún no has publicado nada'), findsNothing);
  });

  testWidgets(
    'la tarjeta muestra categoría, estado y distrito como hashtags',
    (tester) async {
      await tester.pumpWidget(
        _host([
          _post('a', ['https://example.test/1.jpg']).copyWithHashtags(
            category: 'Ropa de cama y abrigo',
            district: 'La Encañada',
            mode: PublicationMode.exchange,
            condition: 'Como nuevo',
          ),
        ]),
      );
      await tester.pumpAndSettle();

      // Sin tildes, minúsculas y sin espacios: los hashtags no pueden llevar
      // espacios, y la categoría de prueba los trae. La modalidad no va como
      // hashtag: la muestra el distintivo junto al título.
      expect(
        find.text('#ropadecamayabrigo  #comonuevo  #laencanada'),
        findsOne,
      );
      expect(find.text('Intercambio'), findsNWidgets(2));
    },
  );
  testWidgets(
    'la descripción larga termina en ..más y se despliega al tocarla',
    (tester) async {
      const long =
          'Mueble de madera en muy buen estado, se entrega en Cajamarca '
          'centro y se coordina la entrega entre las dos personas '
          'interesadas en hacer el intercambio lo antes posible.';
      const short = 'Descripción de prueba.';

      await tester.pumpWidget(
        _host([
          _post('a', [
            'https://example.test/1.jpg',
          ]).copyWithHashtags(description: long),
        ]),
      );
      await tester.pumpAndSettle();

      String shown() => tester
          .widget<RichText>(find.byKey(const Key('post-description')))
          .text
          .toPlainText();

      // Plegada: recortada, con "..más" y sin pasarse de las dos líneas.
      expect(shown(), endsWith('..más'));
      // El recorte cae en un límite de palabra: nunca a media palabra.
      expect(shown(), isNot(contains('j..más')));
      expect(shown().length, lessThan(long.length));
      expect(
        tester.getSize(find.byKey(const Key('post-description'))).height,
        lessThanOrEqualTo(40),
      );

      // Un toque despliega el texto entero y ofrece volver a plegarlo.
      await tester.ensureVisible(find.byKey(const Key('post-description')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('post-description')));
      await tester.pumpAndSettle();
      expect(shown(), contains('lo antes posible'));
      expect(shown(), endsWith('..menos'));
      expect(
        tester.getSize(find.byKey(const Key('post-description'))).height,
        greaterThan(40),
      );

      // Y otro toque lo vuelve a plegar.
      await tester.ensureVisible(find.byKey(const Key('post-description')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('post-description')));
      await tester.pumpAndSettle();
      expect(shown(), endsWith('..más'));

      // Una descripción corta se muestra entera y no ofrece desplegar.
      await tester.pumpWidget(
        _host([
          _post('a', [
            'https://example.test/1.jpg',
          ]).copyWithHashtags(description: short),
        ]),
      );
      await tester.pumpAndSettle();

      expect(shown(), short);
      await tester.ensureVisible(find.byKey(const Key('post-description')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('post-description')));
      await tester.pumpAndSettle();
      expect(shown(), short);
    },
  );

  testWidgets('la cabecera pone el nombre público del autor, no su uid', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host([
        _post('a', [
          'https://example.test/1.jpg',
        ]).copyWithHashtags(authorId: 'otra-persona'),
      ]),
    );
    await tester.pumpAndSettle();

    // El uid es el dato que sale directo de la publicación; el nombre viene del
    // perfil público.
    expect(find.text('otra-persona'), findsNothing);
    expect(find.text('Ana T.'), findsOneWidget);
  });

  testWidgets('sin perfil público la cabecera cae al nombre genérico', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host([
        _post('a', [
          'https://example.test/1.jpg',
        ]).copyWithHashtags(authorId: 'otra-persona'),
      ], authorName: ''),
    );
    await tester.pumpAndSettle();

    expect(find.text('otra-persona'), findsNothing);
    expect(find.text('Usuario de ReHomeIt'), findsOneWidget);
  });

  testWidgets('una descripción de dos líneas justas no se recorta', (
    tester,
  ) async {
    // Regresión: el ancho se medía sobre el contenedor y no sobre el texto,
    // unos 40 px de más. Con eso una descripción que entraba justa se
    // recortaba en silencio, sin "..más" y sin puntos suspensivos.
    await tester.pumpWidget(
      _host([
        _post('a', [
          'https://example.test/1.jpg',
        ]).copyWithHashtags(description: 'Ropa de cama y abrigo'),
      ]),
    );
    await tester.pumpAndSettle();

    final shown = tester
        .widget<RichText>(find.byKey(const Key('post-description')))
        .text
        .toPlainText();
    expect(shown, 'Ropa de cama y abrigo');
  });

  testWidgets('la bandera de reportar solo aparece en publicaciones ajenas', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host([
        _post('propia', ['https://example.test/1.jpg']),
        _post('ajena', [
          'https://example.test/2.jpg',
        ]).copyWithHashtags(authorId: 'otra-persona'),
      ]),
    );
    await tester.pumpAndSettle();

    // Nadie reporta lo suyo: la bandera solo acompaña a la publicación de otra
    // persona (HU19, criterio 1). La publicación ajena va después de la propia
    // y queda fuera de la pantalla, así que el feed se recorre.
    expect(find.bySemanticsLabel('Reportar publicación'), findsNothing);
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('Reportar publicación'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.bySemanticsLabel('Reportar publicación'), findsOneWidget);
  });

  testWidgets(
    'la bandera abre la hoja con los motivos y la cierra al cancelar',
    (tester) async {
      await tester.pumpWidget(
        _host([
          _post('ajena', [
            'https://example.test/1.jpg',
          ]).copyWithHashtags(authorId: 'otra-persona'),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.bySemanticsLabel('Reportar publicación'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Reportar publicación'));
      await tester.pumpAndSettle();

      // En la tarjeta la bandera es solo un ícono con etiqueta de accesibilidad;
      // el título que aparece es el de la hoja.
      expect(find.text('Reportar publicación'), findsOneWidget);
      expect(find.text('Otro motivo'), findsOneWidget);

      // Cerrar la hoja sin enviar no avisa nada: no se registró ningún reporte.
      await tester.tapAt(const Offset(200, 80));
      await tester.pumpAndSettle();
      expect(find.text('Reporte enviado. Lo revisaremos.'), findsNothing);
    },
  );
}

extension on Publication {
  Publication copyWithHashtags({
    String? category,
    String? district,
    PublicationMode? mode,
    String? condition,
    String? description,
    String? authorId,
  }) => Publication(
    id: id,
    authorId: authorId ?? this.authorId,
    title: title,
    category: category ?? this.category,
    condition: condition ?? this.condition,
    description: description ?? this.description,
    details: details,
    district: district ?? this.district,
    mode: mode ?? this.mode,
    status: status,
    images: images,
    publishedAt: publishedAt,
  );
}
