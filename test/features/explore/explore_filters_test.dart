import 'package:flutter_test/flutter_test.dart';
import 'package:rehomeitapp/features/explore/domain/explore_filters.dart';
import 'package:rehomeitapp/shared/domain/publication.dart';

Publication publication({
  required String id,
  required String title,
  required String district,
  required PublicationMode mode,
  required PublicationStatus status,
  required DateTime publishedAt,
  String category = 'Otros',
}) {
  return Publication(
    id: id,
    authorId: 'author-$id',
    title: title,
    category: category,
    condition: 'Usado',
    description: 'Descripción',
    details: const [],
    district: district,
    mode: mode,
    status: status,
    images: const [],
    publishedAt: publishedAt,
  );
}

void main() {
  final items = [
    publication(
      id: 'old',
      title: 'Bicicleta usada',
      district: 'Cajamarca',
      mode: PublicationMode.exchange,
      status: PublicationStatus.published,
      publishedAt: DateTime.utc(2026, 1, 1),
    ),
    publication(
      id: 'new',
      title: 'Bicicleta infantil',
      district: 'Cajamarca',
      mode: PublicationMode.donation,
      status: PublicationStatus.published,
      publishedAt: DateTime.utc(2026, 2, 1),
    ),
    publication(
      id: 'closed',
      title: 'Bicicleta comprometida',
      district: 'Cajamarca',
      mode: PublicationMode.donation,
      status: PublicationStatus.committed,
      publishedAt: DateTime.utc(2026, 3, 1),
    ),
  ];

  test('searches by partial title ignoring case and excludes closed items', () {
    final result = filterAndSortPublications(
      items,
      const ExploreFilters(search: 'BIC'),
    );

    expect(result.map((item) => item.id), ['new', 'old']);
  });

  test('combines mode and district filters', () {
    final result = filterAndSortPublications(
      items,
      const ExploreFilters(
        mode: PublicationMode.exchange,
        district: 'Cajamarca',
      ),
    );

    expect(result.map((item) => item.id), ['old']);
  });

  test('orders newest publications first', () {
    final result = filterAndSortPublications(items, const ExploreFilters());

    expect(result.map((item) => item.id), ['new', 'old']);
  });

  group('categoría', () {
    final categorized = [
      publication(
        id: 'fridge',
        title: 'Refrigeradora',
        district: 'Cajamarca',
        mode: PublicationMode.donation,
        status: PublicationStatus.published,
        publishedAt: DateTime.utc(2026, 1, 1),
        category: 'Electrodomésticos',
      ),
      publication(
        id: 'shoes',
        title: 'Zapatillas blancas',
        district: 'Cajamarca',
        mode: PublicationMode.donation,
        status: PublicationStatus.published,
        publishedAt: DateTime.utc(2026, 2, 1),
        category: 'Calzado',
      ),
      publication(
        id: 'rack',
        title: 'Estante para calzado',
        district: 'Cajamarca',
        mode: PublicationMode.exchange,
        status: PublicationStatus.published,
        publishedAt: DateTime.utc(2026, 3, 1),
        category: 'Muebles',
      ),
    ];

    List<String> idsFor(ExploreFilters filters) => filterAndSortPublications(
      categorized,
      filters,
    ).map((item) => item.id).toList();

    test('el filtro deja solo los bienes de la categoría elegida', () {
      expect(idsFor(const ExploreFilters(category: 'Calzado')), ['shoes']);
    });

    test('la búsqueda encuentra por categoría y por título', () {
      expect(idsFor(const ExploreFilters(search: 'calzado')), [
        'rack',
        'shoes',
      ]);
    });

    test('la búsqueda ignora las tildes', () {
      expect(idsFor(const ExploreFilters(search: 'electrodomesticos')), [
        'fridge',
      ]);
    });

    test('la categoría se combina con la búsqueda y se puede limpiar', () {
      const filters = ExploreFilters(category: 'Muebles', search: 'calzado');
      expect(idsFor(filters), ['rack']);
      expect(filters.isActive, isTrue);
      expect(filters.copyWith(clearCategory: true).category, isNull);
    });
  });
}
