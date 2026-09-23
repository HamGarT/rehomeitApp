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
}) {
  return Publication(
    id: id,
    authorId: 'author-$id',
    title: title,
    category: 'Otros',
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
}
