import 'package:flutter_test/flutter_test.dart';

import 'package:rehomeitapp/features/campaigns/domain/contribution.dart';

void main() {
  group('estado del aporte', () {
    test('cada estado tiene su valor de documento y etiqueta', () {
      expect(ContributionStatus.pending.wireValue, 'pendiente');
      expect(ContributionStatus.confirmed.wireValue, 'confirmado');
      expect(ContributionStatus.rejected.wireValue, 'rechazado');
      expect(ContributionStatus.pending.label, 'Pendiente');
      expect(ContributionStatus.confirmed.label, 'Confirmado');
      expect(ContributionStatus.rejected.label, 'Rechazado');
    });
  });

  group('Contribution.fromMap', () {
    test('lee un aporte pendiente completo', () {
      final contribution = Contribution.fromMap('aporte-1', {
        'campaignId': 'campaign',
        'campaignTitle': 'Abrigo para Cajamarca',
        'organizationId': 'organization',
        'needId': 'ropa',
        'needName': 'Ropa',
        'quantity': 3,
        'contributorId': 'persona',
        'contributorName': 'Persona A.',
        'status': 'pendiente',
        'createdAt': DateTime.utc(2027, 1, 2),
      });

      expect(contribution.campaignId, 'campaign');
      expect(contribution.needId, 'ropa');
      expect(contribution.quantity, 3);
      expect(contribution.status, ContributionStatus.pending);
      expect(contribution.isPending, isTrue);
      expect(contribution.confirmedAt, isNull);
      expect(contribution.rejectionReason, isNull);
    });

    test('lee la confirmación con su sello de tiempo', () {
      final contribution = Contribution.fromMap('aporte-2', {
        'campaignId': 'campaign',
        'needId': 'ropa',
        'quantity': 3,
        'contributorId': 'persona',
        'status': 'confirmado',
        'createdAt': DateTime.utc(2027, 1, 2),
        'confirmedAt': DateTime.utc(2027, 1, 3),
        'confirmedBy': 'organization',
      });

      expect(contribution.status, ContributionStatus.confirmed);
      expect(contribution.isConfirmed, isTrue);
      expect(contribution.confirmedAt, DateTime.utc(2027, 1, 3));
      expect(contribution.confirmedBy, 'organization');
    });

    test('lee el rechazo con su motivo acotado', () {
      final contribution = Contribution.fromMap('aporte-3', {
        'campaignId': 'campaign',
        'needId': 'ropa',
        'quantity': 3,
        'contributorId': 'persona',
        'status': 'rechazado',
        'createdAt': DateTime.utc(2027, 1, 2),
        'rejectedAt': DateTime.utc(2027, 1, 3),
        'rejectedBy': 'organization',
        'rejectionReason': 'No llegó el bien al punto de acopio.',
      });

      expect(contribution.status, ContributionStatus.rejected);
      expect(contribution.isRejected, isTrue);
      expect(contribution.rejectionReason, 'No llegó el bien al punto de acopio.');
    });

    test('un estado desconocido cae a pendiente', () {
      final contribution = Contribution.fromMap('aporte-4', {
        'status': 'en-revision',
      });
      expect(contribution.status, ContributionStatus.pending);
      expect(contribution.quantity, 0);
    });
  });
}
