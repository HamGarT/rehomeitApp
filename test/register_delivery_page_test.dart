import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehomeitapp/app/theme.dart';
import 'package:rehomeitapp/features/delivery/presentation/register_delivery_page.dart';
import 'package:rehomeitapp/shared/domain/publication.dart';

void main() {
  testWidgets('formulario de entrega muestra privacidad y solo datos mínimos', (
    tester,
  ) async {
    final publication = Publication(
      id: 'publication-id',
      authorId: 'donor-id',
      title: 'Mesa',
      category: 'Hogar',
      condition: 'Usado',
      description: 'Mesa en buen estado',
      details: const [],
      district: 'Cajamarca',
      mode: PublicationMode.donation,
      deliveryType: DeliveryType.owner,
      status: PublicationStatus.published,
      images: const ['https://example.test/mesa.jpg'],
      publishedAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(brightness: Brightness.light),
          home: RegisterDeliveryPage(publication: publication),
        ),
      ),
    );

    expect(
      find.textContaining('Solo se registran las iniciales y el distrito'),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.textContaining('Iniciales del destinatario'), findsOneWidget);
    expect(find.textContaining('Distrito'), findsOneWidget);
    expect(find.textContaining('DNI'), findsNothing);
    expect(find.textContaining('Dirección'), findsNothing);
    expect(find.textContaining('Teléfono'), findsNothing);
    expect(find.textContaining('Correo'), findsNothing);
  });
}
