import 'package:flutter_test/flutter_test.dart';
import 'package:rehomeitapp/features/publishing/domain/publish_draft.dart';
import 'package:rehomeitapp/shared/domain/publication.dart';

void main() {
  group('PublishDraft', () {
    test('requires a delivery type for donations', () {
      const draft = PublishDraft(mode: PublicationMode.donation);

      expect(draft.modeCompleted, isFalse);
      expect(draft.missingModeFields, contains('Forma de entrega'));
    });

    test('does not request a delivery type for exchanges', () {
      const draft = PublishDraft(mode: PublicationMode.exchange);

      expect(draft.modeCompleted, isTrue);
      expect(draft.deliveryMethod, isNull);
    });
  });

  test('serializes donation values with one canonical convention', () {
    final publication = Publication(
      id: 'pub-1',
      authorId: 'user-1',
      title: 'Bicicleta',
      category: 'Otros',
      condition: 'Usado',
      description: 'En buen estado',
      details: const [ItemDetail(name: 'Color', value: 'Verde')],
      district: 'Cajamarca',
      mode: PublicationMode.donation,
      deliveryType: DeliveryType.volunteer,
      status: PublicationStatus.published,
      images: const ['https://example.test/photo.jpg'],
      publishedAt: DateTime.utc(2026, 9, 22),
    );

    final map = publication.toMap();

    expect(map['mode'], 'donacion');
    expect(map['deliveryType'], 'voluntario');
    expect(map['status'], 'publicada');
    expect(map, isNot(contains('price')));
    expect(map, isNot(contains('amount')));
  });

  test('derives time-based publication status from the delivery milestone', () {
    final deliveredAt = DateTime.utc(2026, 9, 20, 12);
    final publication = Publication(
      id: 'pub-2',
      authorId: 'user-1',
      title: 'Mesa',
      category: 'Muebles',
      condition: 'Usado',
      description: 'Mesa de madera',
      details: const [],
      district: 'Cajamarca',
      mode: PublicationMode.exchange,
      status: PublicationStatus.delivered,
      images: const ['https://example.test/photo.jpg'],
      publishedAt: DateTime.utc(2026, 9, 18),
      statusDates: {PublicationStatus.delivered: deliveredAt},
    );

    expect(
      publication.effectiveStatus(deliveredAt.add(const Duration(hours: 48))),
      PublicationStatus.pendingConfirmation,
    );
    expect(
      publication.effectiveStatus(deliveredAt.add(const Duration(hours: 72))),
      PublicationStatus.closedWithoutConfirmation,
    );
  });
}
