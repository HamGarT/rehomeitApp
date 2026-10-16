import 'package:flutter_test/flutter_test.dart';

import 'package:rehomeitapp/features/campaigns/domain/campaign.dart';
import 'package:rehomeitapp/features/campaigns/domain/campaign_draft.dart';

Campaign _campaign({
  List<CampaignNeed> needs = const [],
  CampaignStatus status = CampaignStatus.active,
  DateTime? closeAt,
  Map<String, int> contributions = const {},
  int confirmedContributions = 0,
  int contributorsCount = 0,
  String? destinationNote,
  DateTime? summaryNotifiedAt,
}) => Campaign(
  id: 'campaign',
  organizationId: 'organization',
  organizationName: 'Organización Solidaria',
  title: 'Abrigo para Cajamarca',
  description: 'Recolectamos abrigo para familias de la zona.',
  district: 'Cajamarca',
  closeAt: closeAt ?? DateTime.utc(2027, 1, 20),
  collectionPoint: const CollectionPoint(
    name: 'Local comunal',
    address: 'Jr. Amalia 123',
    openingHours: 'Lunes a sábado, 9 a 17 h',
  ),
  needs: needs,
  contributions: contributions,
  confirmedContributions: confirmedContributions,
  contributorsCount: contributorsCount,
  destinationNote: destinationNote,
  summaryNotifiedAt: summaryNotifiedAt,
  status: status,
  createdAt: DateTime.utc(2027, 1, 1),
  updatedAt: DateTime.utc(2027, 1, 1),
);

const _requiredTen = CampaignNeed(
  id: 'ropa',
  name: 'Ropa',
  requiredQuantity: 10,
  contributedQuantity: 0,
);

void main() {
  group('avance de campaña', () {
    test('una campaña sin aportes tiene 0 %', () {
      expect(_campaign(needs: const [_requiredTen]).progressPercent, 0);
    });

    test('suma todas las necesidades y calcula 53.33 %', () {
      final campaign = _campaign(
        needs: const [
          CampaignNeed(
            id: 'ropa',
            name: 'Ropa',
            requiredQuantity: 10,
            contributedQuantity: 6,
          ),
          CampaignNeed(
            id: 'frazadas',
            name: 'Frazadas',
            requiredQuantity: 5,
            contributedQuantity: 2,
          ),
        ],
      );
      expect(campaign.totalRequired, 15);
      expect(campaign.totalContributed, 8);
      expect(campaign.progressPercent, closeTo(53.333, 0.001));
    });

    test('una campaña completa tiene 100 %', () {
      final campaign = _campaign(
        needs: const [
          CampaignNeed(
            id: 'ropa',
            name: 'Ropa',
            requiredQuantity: 10,
            contributedQuantity: 10,
          ),
        ],
      );
      expect(campaign.progressPercent, 100);
      expect(campaign.progressForIndicator, 1);
    });

    test('conserva el sobreaporte y limita solo el indicador', () {
      final campaign = _campaign(
        needs: const [
          CampaignNeed(
            id: 'ropa',
            name: 'Ropa',
            requiredQuantity: 10,
            contributedQuantity: 14,
          ),
        ],
      );
      expect(campaign.progressPercent, 140);
      expect(campaign.progressForIndicator, 1);
    });

    test('una necesidad igualada o superada está cubierta', () {
      expect(
        const CampaignNeed(
          id: 'a',
          name: 'Agua',
          requiredQuantity: 5,
          contributedQuantity: 5,
        ).isCovered,
        isTrue,
      );
      expect(
        const CampaignNeed(
          id: 'a',
          name: 'Agua',
          requiredQuantity: 5,
          contributedQuantity: 8,
        ).isCovered,
        isTrue,
      );
    });
  });

  group('contadores de aportes confirmados', () {
    test('contributedFor lee el mapa de aportes de la campaña', () {
      final campaign = _campaign(
        needs: const [_requiredTen],
        contributions: const {'ropa': 4},
      );
      expect(campaign.contributedFor('ropa'), 4);
      expect(campaign.totalContributed, 4);
    });

    test('contributedFor cae al valor heredado si no hay mapa', () {
      final campaign = _campaign(
        needs: const [
          CampaignNeed(
            id: 'ropa',
            name: 'Ropa',
            requiredQuantity: 10,
            contributedQuantity: 3,
          ),
        ],
      );
      expect(campaign.contributedFor('ropa'), 3);
    });

    test('isNeedCovered usa el contador confirmado', () {
      final campaign = _campaign(
        needs: const [_requiredTen],
        contributions: const {'ropa': 10},
      );
      expect(campaign.isNeedCovered(_requiredTen), isTrue);
    });

    test('el mapa serializado conserva los aportes confirmados', () {
      final campaign = _campaign(
        needs: const [_requiredTen],
        contributions: const {'ropa': 7},
      );
      final restored = Campaign.fromMap('campaign', campaign.toMap());
      expect(restored.contributions, {'ropa': 7});
      expect(restored.contributedFor('ropa'), 7);
    });
  });

  test('el cierre efectivo considera estado o fecha', () {
    final now = DateTime.utc(2027, 1, 10, 12);
    expect(
      _campaign(closeAt: DateTime.utc(2027, 1, 10, 11)).isClosedAt(now),
      isTrue,
    );
    expect(
      _campaign(
        closeAt: DateTime.utc(2027, 2),
        status: CampaignStatus.closed,
      ).isClosedAt(now),
      isTrue,
    );
    expect(
      _campaign(closeAt: DateTime.utc(2027, 1, 10, 13)).isClosedAt(now),
      isFalse,
    );
  });

  group('resumen de cierre (HU17)', () {
    final now = DateTime.utc(2027, 1, 10, 12);
    const needs = [
      _requiredTen,
      CampaignNeed(
        id: 'frazadas',
        name: 'Frazadas',
        requiredQuantity: 5,
        contributedQuantity: 0,
      ),
    ];

    test('consolida requerido y aportado por necesidad y en total', () {
      final summary = _campaign(
        needs: needs,
        contributions: const {'ropa': 12, 'frazadas': 2},
        confirmedContributions: 5,
        contributorsCount: 3,
        destinationNote: 'Se entregó a familias del caserío.',
      ).closureSummary();

      expect(summary.needs.map((need) => need.contributedQuantity), [12, 2]);
      expect(summary.needs.first.isCovered, isTrue);
      expect(summary.needs.last.isCovered, isFalse);
      expect(summary.totalRequired, 15);
      expect(summary.totalContributed, 14);
      expect(summary.confirmedContributions, 5);
      expect(summary.contributorsCount, 3);
      expect(summary.district, 'Cajamarca');
      expect(summary.hasDestinationNote, isTrue);
    });

    test('sin descripción del destino, el resumen lo dice', () {
      expect(
        _campaign(destinationNote: '  ').closureSummary().hasDestinationNote,
        isFalse,
      );
    });

    test('los campos del resumen sobreviven a la serialización', () {
      final restored = Campaign.fromMap(
        'campaign',
        _campaign(
          confirmedContributions: 4,
          contributorsCount: 2,
          destinationNote: 'Destino',
          summaryNotifiedAt: now,
        ).toMap(),
      );
      expect(restored.confirmedContributions, 4);
      expect(restored.contributorsCount, 2);
      expect(restored.destinationNote, 'Destino');
      // `Timestamp.toDate` devuelve hora local; se compara en UTC.
      expect(restored.summaryNotifiedAt?.toUtc(), now);
    });

    test('un documento anterior a HU17 arranca en cero', () {
      final legacy = _campaign().toMap()
        ..remove('confirmedContributions')
        ..remove('contributorsCount')
        ..remove('destinationNote')
        ..remove('summaryNotifiedAt');
      final restored = Campaign.fromMap('campaign', legacy);
      expect(restored.confirmedContributions, 0);
      expect(restored.contributorsCount, 0);
      expect(restored.destinationNote, isNull);
      expect(restored.summaryNotifiedAt, isNull);
    });

    test('la dueña describe el destino solo con la campaña cerrada', () {
      final open = _campaign(closeAt: DateTime.utc(2027, 2));
      final closed = _campaign(closeAt: DateTime.utc(2027, 1, 1));
      expect(
        open.canEditDestinationNote(
          userId: 'organization',
          isOrganization: true,
          now: now,
        ),
        isFalse,
      );
      expect(
        closed.canEditDestinationNote(
          userId: 'organization',
          isOrganization: true,
          now: now,
        ),
        isTrue,
      );
      expect(
        closed.canEditDestinationNote(
          userId: 'otra',
          isOrganization: true,
          now: now,
        ),
        isFalse,
      );
    });

    test('el aviso del resumen se debe una vez, cerrada, a dueña o admin', () {
      final closed = _campaign(closeAt: DateTime.utc(2027, 1, 1));
      bool should(
        Campaign campaign, {
        String userId = 'organization',
        bool isOrganization = true,
        bool isAdmin = false,
      }) => campaign.shouldNotifySummary(
        userId: userId,
        isOrganization: isOrganization,
        isAdmin: isAdmin,
        now: now,
      );

      expect(should(closed), isTrue);
      expect(
        should(closed, userId: 'admin', isOrganization: false, isAdmin: true),
        isTrue,
      );
      expect(should(closed, userId: 'otra'), isFalse);
      expect(should(_campaign(closeAt: DateTime.utc(2027, 2))), isFalse);
      expect(
        should(
          _campaign(closeAt: DateTime.utc(2027, 1, 1), summaryNotifiedAt: now),
        ),
        isFalse,
      );
    });
  });

  group('validación del borrador', () {
    final now = DateTime.utc(2027, 1, 1);

    CampaignDraft validDraft() => CampaignDraft(
      title: 'Campaña',
      description: 'Descripción',
      district: 'Cajamarca',
      closeAt: DateTime.utc(2027, 1, 2),
      collectionPointName: 'Local',
      collectionPointAddress: 'Dirección',
      collectionPointOpeningHours: '9 a 17 h',
      needs: const [
        CampaignNeedDraft(id: 'ropa', name: 'Ropa', requiredQuantity: 2),
      ],
    );

    test('acepta un borrador completo', () {
      expect(validDraft().validationErrors(now), isEmpty);
    });

    test(
      'rechaza fecha pasada, ausencia de necesidades y cantidad inválida',
      () {
        final empty = const CampaignDraft();
        expect(
          empty.validationErrors(now),
          contains('Agrega al menos una necesidad.'),
        );

        final invalid = CampaignDraft(
          title: 'Campaña',
          description: 'Descripción',
          district: 'Cajamarca',
          closeAt: DateTime.utc(2026),
          collectionPointName: 'Local',
          collectionPointAddress: 'Dirección',
          collectionPointOpeningHours: 'Horario',
          needs: const [CampaignNeedDraft(id: 'ropa', name: 'Ropa')],
        );
        expect(
          invalid.validationErrors(now),
          containsAll([
            'Selecciona una fecha de cierre futura.',
            'Cada cantidad requerida debe ser mayor que cero.',
          ]),
        );
      },
    );
  });
}
