import 'package:flutter_test/flutter_test.dart';
import 'package:rehomeitapp/features/publishing/data/pending_publication_store.dart';
import 'package:rehomeitapp/shared/domain/publication.dart';

void main() {
  group('PendingPublication', () {
    test('sobrevive al viaje de ida y vuelta por JSON', () {
      const pending = PendingPublication(
        publicationId: 'abc123',
        authorId: 'author',
        title: 'Casaca',
        category: 'Ropa',
        condition: 'Usado',
        description: 'Abrigada',
        details: [ItemDetail(name: 'Talla', value: 'M')],
        district: 'Cajamarca',
        mode: PublicationMode.donation,
        deliveryType: DeliveryType.volunteer,
        photos: [
          PendingPhoto(
            index: 0,
            localPath: '/tmp/foto_0.jpg',
            extension: 'jpg',
          ),
          PendingPhoto(
            index: 1,
            localPath: '/tmp/foto_1.png',
            extension: 'png',
          ),
        ],
      );

      final restored = PendingPublication.fromJson(pending.toJson());

      expect(restored.publicationId, 'abc123');
      expect(restored.mode, PublicationMode.donation);
      expect(restored.deliveryType, DeliveryType.volunteer);
      expect(restored.details.single.value, 'M');
      expect(restored.photos.map((photo) => photo.contentType), [
        'image/jpeg',
        'image/png',
      ]);
    });

    test('un intercambio no lleva forma de entrega', () {
      const pending = PendingPublication(
        publicationId: 'x',
        authorId: 'a',
        title: 't',
        category: 'c',
        condition: 'c',
        description: 'd',
        details: [],
        district: 'Jesús',
        mode: PublicationMode.exchange,
        deliveryType: null,
        photos: [],
      );

      final json = pending.toJson();

      expect(json['deliveryType'], isNull);
      expect(PendingPublication.fromJson(json).mode, PublicationMode.exchange);
    });
  });
}
