import 'package:flutter_test/flutter_test.dart';

import 'package:rehomeitapp/features/campaigns/domain/campaign.dart';
import 'package:rehomeitapp/features/campaigns/domain/campaign_draft.dart';

Campaign _campaign({
  List<CampaignNeed> needs = const [],
  CampaignStatus status = CampaignStatus.active,
  DateTime? closeAt,
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
