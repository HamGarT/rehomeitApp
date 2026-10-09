import 'package:flutter_test/flutter_test.dart';
import 'package:rehomeitapp/shared/domain/publication.dart';

Publication _publication({
  PublicationMode mode = PublicationMode.donation,
  DeliveryType? deliveryType = DeliveryType.volunteer,
  PublicationStatus status = PublicationStatus.published,
  String? volunteerId,
  Map<PublicationStatus, DateTime> statusDates = const {},
}) {
  return Publication(
    id: 'p1',
    authorId: 'author',
    title: 'Silla',
    category: 'Muebles',
    condition: 'Usado',
    description: '',
    details: const [],
    district: 'Cajamarca',
    mode: mode,
    deliveryType: deliveryType,
    status: status,
    images: const [],
    publishedAt: DateTime.utc(2026, 10, 1),
    statusDates: statusDates,
    volunteerId: volunteerId,
  );
}

void main() {
  group('acciones por rol', () {
    test('un tercero asume el recojo; el autor no', () {
      final publication = _publication();
      expect(publication.canAssumePickup('other'), isTrue);
      expect(publication.canAssumePickup('author'), isFalse);
      expect(
        _publication(deliveryType: DeliveryType.owner).canAssumePickup('other'),
        isFalse,
      );
    });

    test(
      'comprometida: el autor confirma el recojo y ambos pueden liberar',
      () {
        final publication = _publication(
          status: PublicationStatus.committed,
          volunteerId: 'vol',
        );
        expect(publication.canConfirmHandoff('author'), isTrue);
        expect(publication.canConfirmHandoff('vol'), isFalse);
        expect(publication.canReleaseCommitment('author'), isTrue);
        expect(publication.canReleaseCommitment('vol'), isTrue);
        expect(publication.canReleaseCommitment('other'), isFalse);
        expect(publication.canWithdraw('author'), isFalse);
      },
    );

    test(
      'registra la entrega el voluntario tras recoger o el donante directo',
      () {
        final pickedUp = _publication(
          status: PublicationStatus.pickedUp,
          volunteerId: 'vol',
        );
        expect(pickedUp.canRegisterDelivery('vol'), isTrue);
        expect(pickedUp.canRegisterDelivery('author'), isFalse);

        final direct = _publication(deliveryType: DeliveryType.owner);
        expect(direct.canRegisterDelivery('author'), isTrue);
        expect(direct.canRegisterDelivery('other'), isFalse);
      },
    );

    test('intercambio: propone un tercero mientras está publicada', () {
      final exchange = _publication(
        mode: PublicationMode.exchange,
        deliveryType: null,
      );
      expect(exchange.canProposeExchange('other'), isTrue);
      expect(exchange.canProposeExchange('author'), isFalse);
      expect(exchange.canAssumePickup('other'), isFalse);
    });

    test(
      'la conversación es con el autor, o con el voluntario si eres el autor',
      () {
        final publication = _publication(
          status: PublicationStatus.committed,
          volunteerId: 'vol',
        );
        expect(publication.conversationCounterpart('other'), 'author');
        expect(publication.conversationCounterpart('author'), 'vol');
        expect(_publication().conversationCounterpart('author'), isNull);
      },
    );
  });

  group('ruta esperada', () {
    test('cada modalidad recorre sus propios hitos', () {
      expect(_publication().expectedPath, [
        PublicationStatus.published,
        PublicationStatus.committed,
        PublicationStatus.pickedUp,
        PublicationStatus.delivered,
        PublicationStatus.confirmed,
      ]);
      expect(_publication(deliveryType: DeliveryType.owner).expectedPath, [
        PublicationStatus.published,
        PublicationStatus.confirmed,
      ]);
      expect(
        _publication(
          mode: PublicationMode.exchange,
          deliveryType: null,
        ).expectedPath,
        [
          PublicationStatus.published,
          PublicationStatus.committed,
          PublicationStatus.delivered,
          PublicationStatus.confirmed,
        ],
      );
    });

    test('el intercambio solo expone al autor como actor', () {
      final donation = _publication(volunteerId: 'vol');
      expect(donation.milestoneActorId(PublicationStatus.committed), 'vol');
      expect(donation.milestoneActorId(PublicationStatus.pickedUp), 'author');

      final exchange = _publication(
        mode: PublicationMode.exchange,
        deliveryType: null,
      );
      expect(exchange.milestoneActorId(PublicationStatus.published), 'author');
      expect(exchange.milestoneActorId(PublicationStatus.committed), isNull);
    });
  });

  group('recorrido', () {
    final published = DateTime.utc(2026, 10, 1);
    final delivered = DateTime.utc(2026, 10, 3);

    test('omite el compromiso si la publicación volvió a estar disponible', () {
      final publication = _publication(
        statusDates: {
          PublicationStatus.published: published,
          PublicationStatus.committed: DateTime.utc(2026, 10, 2),
        },
      );
      expect(
        publication.milestones(DateTime.utc(2026, 10, 4)).map((m) => m.status),
        [PublicationStatus.published],
      );
    });

    test('agrega los hitos por vencimiento a partir de la entrega', () {
      final publication = _publication(
        status: PublicationStatus.delivered,
        statusDates: {
          PublicationStatus.published: published,
          PublicationStatus.delivered: delivered,
        },
      );
      final afterThreeDays = publication.milestones(
        delivered.add(const Duration(hours: 121)),
      );
      expect(afterThreeDays.map((m) => m.status), [
        PublicationStatus.published,
        PublicationStatus.delivered,
        PublicationStatus.pendingConfirmation,
        PublicationStatus.closedWithoutConfirmation,
      ]);
      expect(
        afterThreeDays[2].at,
        delivered.add(Publication.pendingConfirmationAfter),
      );
      expect(
        publication.milestones(delivered.add(const Duration(hours: 1))).length,
        2,
      );
    });
  });
}
