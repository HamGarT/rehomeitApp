import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rehomeitapp/features/delivery/domain/delivery_draft.dart';

void main() {
  group('DeliveryDraft', () {
    test('informa todos los campos obligatorios faltantes', () {
      const draft = DeliveryDraft();

      expect(
        draft.missingFields,
        containsAll([
          'fotografía de evidencia',
          'iniciales del destinatario',
          'distrito',
        ]),
      );
      expect(draft.isComplete, isFalse);
    });

    test('normaliza iniciales y acepta un distrito de Cajamarca', () {
      final draft = DeliveryDraft(
        photo: File('/tmp/evidencia.jpg'),
        recipientInitials: ' m. r. ',
        district: 'Cajamarca',
      );

      expect(draft.normalizedInitials, 'M.R.');
      expect(draft.validate(), isNull);
      expect(draft.isComplete, isTrue);
    });

    test('rechaza distritos fuera de la lista', () {
      final draft = DeliveryDraft(
        photo: File('/tmp/evidencia.jpg'),
        recipientInitials: 'A.B.',
        district: 'Distrito inventado',
      );

      expect(draft.validate(), contains('distrito válido'));
    });
  });
}
