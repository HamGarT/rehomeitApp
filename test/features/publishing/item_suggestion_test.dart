import 'package:flutter_test/flutter_test.dart';
import 'package:rehomeitapp/features/publishing/domain/item_suggestion.dart';

void main() {
  group('ItemSuggestion.prohibitedContent', () {
    test('reconoce documentos de identidad, tarjetas, armas y rostros', () {
      final suggestion = ItemSuggestion.fromJson({
        'recognized': false,
        'prohibitedContent': [
          'documento_identidad',
          'tarjeta_pago',
          'arma',
          'rostro',
        ],
        'title': '',
        'category': null,
        'condition': null,
        'description': '',
        'details': const [],
      });

      expect(suggestion.prohibitedContent, {
        ProhibitedContent.identityDocument,
        ProhibitedContent.paymentCard,
        ProhibitedContent.weapon,
        ProhibitedContent.face,
      });
    });

    test('ignora valores desconocidos y datos duplicados', () {
      final suggestion = ItemSuggestion.fromJson({
        'recognized': true,
        'prohibitedContent': ['arma', 'arma', 'otro'],
        'title': 'Mesa',
        'category': null,
        'condition': null,
        'description': '',
        'details': const [],
      });

      expect(suggestion.prohibitedContent, [ProhibitedContent.weapon]);
    });

    test('queda vacío cuando el modelo no reporta contenido prohibido', () {
      final suggestion = ItemSuggestion.fromJson({
        'recognized': true,
        'title': 'Mesa',
        'category': null,
        'condition': null,
        'description': '',
        'details': const [],
      });

      expect(suggestion.prohibitedContent, isEmpty);
    });
  });
}
