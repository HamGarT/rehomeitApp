import 'package:flutter_test/flutter_test.dart';
import 'package:rehomeitapp/shared/domain/publication.dart';

Publication _publication({
  PublicationMode mode = PublicationMode.donation,
  DeliveryType? deliveryType = DeliveryType.volunteer,
  PublicationStatus status = PublicationStatus.published,
  String? volunteerId,
  String? counterpartUserId,
  Map<PublicationStatus, DateTime> statusDates = const {},
  String? firstConfirmedBy,
}) {
  return Publication(
    firstConfirmedBy: firstConfirmedBy,
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
    counterpartUserId: counterpartUserId,
  );
}

void main() {
  group('acciones por rol', () {
    test('la moderación retira solo lo publicado o comprometido', () {
      // Espejo de `validAdminRemoval`: desde recogida en adelante el bien ya
      // cambió de manos y la consola solo ofrece desestimar (HU19-10).
      const removable = {
        PublicationStatus.published,
        PublicationStatus.committed,
      };
      for (final status in PublicationStatus.values) {
        expect(
          _publication(status: status).isRemovableByModeration,
          removable.contains(status),
          reason: '$status',
        );
      }
    });

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

    test('donación: conversan el autor y su voluntario, nadie más', () {
      final publication = _publication(
        status: PublicationStatus.committed,
        volunteerId: 'vol',
      );
      expect(publication.conversationCounterpart('author'), 'vol');
      expect(publication.conversationCounterpart('vol'), 'author');
      expect(publication.conversationCounterpart('other'), isNull);
      // Sin voluntario no hay con quién hablar, ni siquiera para el autor.
      expect(_publication().conversationCounterpart('author'), isNull);
      expect(_publication().conversationCounterpart('other'), isNull);
    });

    test('intercambio: conversan el autor y quien aceptó, nadie más', () {
      final accepted = _publication(
        mode: PublicationMode.exchange,
        deliveryType: null,
        status: PublicationStatus.committed,
        counterpartUserId: 'partner',
      );
      expect(accepted.conversationCounterpart('author'), 'partner');
      expect(accepted.conversationCounterpart('partner'), 'author');
      expect(accepted.conversationCounterpart('other'), isNull);

      final open = _publication(mode: PublicationMode.exchange);
      expect(open.conversationCounterpart('other'), isNull);
      expect(open.conversationCounterpart('author'), isNull);
    });

    test('intercambio: Mis intercambios sigue accesible tras aceptar', () {
      final open = _publication(mode: PublicationMode.exchange);
      expect(open.canViewExchangeActivity('author'), isTrue);
      expect(open.canViewExchangeActivity('other'), isFalse);

      final accepted = _publication(
        mode: PublicationMode.exchange,
        status: PublicationStatus.committed,
        counterpartUserId: 'partner',
      );
      expect(accepted.canViewExchangeActivity('author'), isTrue);
      expect(accepted.canViewExchangeActivity('partner'), isTrue);
      expect(accepted.canViewExchangeActivity('other'), isFalse);

      final cancelled = _publication(
        mode: PublicationMode.exchange,
        status: PublicationStatus.cancelled,
      );
      expect(cancelled.canViewExchangeActivity('author'), isFalse);
      expect(_publication().canViewExchangeActivity('author'), isFalse);
    });
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
          PublicationStatus.confirmed,
        ],
      );
    });

    test('el intercambio no muestra la primera confirmación como hito', () {
      // HU14-2 lista tres hitos para el intercambio; "Entregada" sigue siendo
      // el estado (HU07-15), pero no entra en el recorrido.
      final exchange = _publication(
        mode: PublicationMode.exchange,
        deliveryType: null,
        status: PublicationStatus.delivered,
        statusDates: {
          PublicationStatus.published: DateTime.utc(2026, 10, 1),
          PublicationStatus.committed: DateTime.utc(2026, 10, 2),
          PublicationStatus.delivered: DateTime.utc(2026, 10, 3),
        },
      );
      expect(
        exchange.milestones(DateTime.utc(2026, 10, 3, 1)).map((m) => m.status),
        [PublicationStatus.published, PublicationStatus.committed],
      );
      expect(
        exchange.effectiveStatus(DateTime.utc(2026, 10, 3, 1)),
        PublicationStatus.delivered,
      );
    });

    test('el intercambio sabe a quién le falta confirmar', () {
      // HU07-15 y 19: la parte pendiente es la que no firmó la primera
      // confirmación; sin el dato (intercambios anteriores) no se adivina.
      Publication exchange({String? firstConfirmedBy}) => _publication(
        mode: PublicationMode.exchange,
        deliveryType: null,
        counterpartUserId: 'proposer',
        firstConfirmedBy: firstConfirmedBy,
      );
      expect(
        exchange(firstConfirmedBy: 'author').pendingExchangeConfirmerId,
        'proposer',
      );
      expect(
        exchange(firstConfirmedBy: 'proposer').pendingExchangeConfirmerId,
        'author',
      );
      expect(exchange().pendingExchangeConfirmerId, isNull);
      expect(
        _publication(firstConfirmedBy: 'author').pendingExchangeConfirmerId,
        isNull,
      );
      final map = exchange(firstConfirmedBy: 'author').toMap();
      expect(Publication.fromMap('p1', map).firstConfirmedBy, 'author');
      expect(_publication().toMap().containsKey('firstConfirmedBy'), isFalse);
    });

    test('se reporta lo ajeno mientras la operación siga abierta', () {
      final now = DateTime.utc(2026, 10, 12);
      expect(_publication().canReport('other', now), isTrue);
      expect(_publication().canReport('author', now), isFalse);
      for (final status in [
        PublicationStatus.confirmed,
        PublicationStatus.cancelled,
        PublicationStatus.removed,
      ]) {
        expect(
          _publication(status: status).canReport('other', now),
          isFalse,
          reason: '$status',
        );
      }
      final closedWithoutConfirmation = _publication(
        status: PublicationStatus.delivered,
        statusDates: {PublicationStatus.delivered: DateTime.utc(2026, 10, 1)},
      );
      expect(closedWithoutConfirmation.canReport('other', now), isFalse);
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
