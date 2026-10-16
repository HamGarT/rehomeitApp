import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rehomeitapp/app/theme.dart';
import 'package:rehomeitapp/features/auth/domain/app_user.dart';
import 'package:rehomeitapp/features/auth/presentation/auth_controller.dart';
import 'package:rehomeitapp/features/campaigns/domain/campaign.dart';
import 'package:rehomeitapp/features/campaigns/domain/campaign_draft.dart';
import 'package:rehomeitapp/features/campaigns/domain/contribution.dart';
import 'package:rehomeitapp/features/campaigns/presentation/campaign_controller.dart';
import 'package:rehomeitapp/features/campaigns/presentation/campaign_detail_page.dart';
import 'package:rehomeitapp/features/campaigns/presentation/campaign_form_page.dart';
import 'package:rehomeitapp/features/campaigns/presentation/campaigns_page.dart';
import 'package:rehomeitapp/features/campaigns/presentation/widgets/campaign_progress.dart';
import 'package:rehomeitapp/features/campaigns/presentation/widgets/pending_contribution_card.dart';

const _uid = 'account';

Campaign _campaign({
  CampaignStatus status = CampaignStatus.active,
  DateTime? closeAt,
  int required = 10,
  int contributed = 4,
  String organizationId = _uid,
  String? destinationNote,
  DateTime? summaryNotifiedAt,
}) => Campaign(
  id: 'campaign-id',
  organizationId: organizationId,
  confirmedContributions: 3,
  contributorsCount: 2,
  destinationNote: destinationNote,
  summaryNotifiedAt: summaryNotifiedAt,
  organizationName: 'Organización Solidaria',
  title: 'Abrigo para Cajamarca',
  description: 'Recolectamos ropa de abrigo.',
  district: 'Cajamarca',
  closeAt: closeAt ?? DateTime.utc(2030, 1, 20),
  collectionPoint: const CollectionPoint(
    name: 'Local comunal',
    address: 'Jr. Amalia 123',
    openingHours: '9 a 17 h',
  ),
  needs: [
    CampaignNeed(
      id: 'ropa',
      name: 'Ropa',
      requiredQuantity: required,
      contributedQuantity: contributed,
    ),
  ],
  status: status,
  createdAt: DateTime.utc(2026, 10, 1),
  updatedAt: DateTime.utc(2026, 10, 1),
);

Widget _host({
  required Widget child,
  required CampaignAccess access,
  List<Campaign> campaigns = const [],
  Campaign? detail,
}) => ProviderScope(
  overrides: [
    authStateProvider.overrideWith(
      (ref) => Stream.value(const AppUser(uid: _uid)),
    ),
    campaignAccessProvider.overrideWith((ref, id) => Stream.value(access)),
    campaignsProvider.overrideWith((ref) => Stream.value(campaigns)),
    if (detail != null)
      campaignProvider.overrideWith((ref, id) => Stream.value(detail)),
  ],
  child: MaterialApp(
    theme: buildAppTheme(brightness: Brightness.light),
    home: Scaffold(body: child),
  ),
);

/// El botón de cierre va al final de un ListView perezoso: sin desplazar no
/// se construye y `findsNothing` pasaría aunque existiera.
Future<void> _scrollToEnd(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('usuario normal no ve Crear campaña', (tester) async {
    await tester.pumpWidget(
      _host(
        child: const CampaignsPage(),
        access: const CampaignAccess(
          role: CampaignAccess.userRole,
          organizationName: 'Persona',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Crear campaña'), findsNothing);
  });

  testWidgets('organización sí ve Crear campaña', (tester) async {
    await tester.pumpWidget(
      _host(
        child: const CampaignsPage(),
        access: const CampaignAccess(
          role: CampaignAccess.organizationRole,
          organizationName: 'Organización Solidaria',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Crear campaña'), findsOneWidget);
  });

  testWidgets('el formulario exige al menos una necesidad', (tester) async {
    await tester.pumpWidget(
      _host(
        child: const CampaignFormPage(),
        access: const CampaignAccess(
          role: CampaignAccess.organizationRole,
          organizationName: 'Organización Solidaria',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('campaign-form-submit')));
    await tester.pump();
    expect(find.text('Agrega al menos una necesidad.'), findsOneWidget);
  });

  testWidgets('una campaña cerrada no muestra edición', (tester) async {
    final closed = _campaign(status: CampaignStatus.closed);
    await tester.pumpWidget(
      _host(
        child: CampaignDetailPage(initial: closed),
        detail: closed,
        access: const CampaignAccess(
          role: CampaignAccess.organizationRole,
          organizationName: 'Organización Solidaria',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('edit-campaign-button')), findsNothing);
    await _scrollToEnd(tester);
    expect(find.byKey(const Key('close-campaign-button')), findsNothing);
  });

  testWidgets('la organización dueña puede cerrar su campaña activa', (
    tester,
  ) async {
    final active = _campaign();
    await tester.pumpWidget(
      _host(
        child: CampaignDetailPage(initial: active),
        detail: active,
        access: const CampaignAccess(
          role: CampaignAccess.organizationRole,
          organizationName: 'Organización Solidaria',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _scrollToEnd(tester);
    expect(find.byKey(const Key('close-campaign-button')), findsOneWidget);
  });

  testWidgets('un usuario normal no puede cerrar una campaña', (tester) async {
    final active = _campaign();
    await tester.pumpWidget(
      _host(
        child: CampaignDetailPage(initial: active),
        detail: active,
        access: const CampaignAccess(
          role: CampaignAccess.userRole,
          organizationName: 'Persona',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _scrollToEnd(tester);
    expect(find.byKey(const Key('close-campaign-button')), findsNothing);
  });

  testWidgets('una campaña cerrada muestra el resumen y la dueña puede '
      'describir el destino', (tester) async {
    final closed = _campaign(
      status: CampaignStatus.closed,
      summaryNotifiedAt: DateTime.utc(2026, 10, 1),
    );
    await tester.pumpWidget(
      _host(
        child: CampaignDetailPage(initial: closed),
        detail: closed,
        access: const CampaignAccess(
          role: CampaignAccess.organizationRole,
          organizationName: 'Organización Solidaria',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _scrollToEnd(tester);

    expect(find.text('Resumen de cierre'), findsOneWidget);
    expect(find.text('4 de 10'), findsOneWidget);
    expect(find.text('3 aportes confirmados de 2 personas'), findsOneWidget);
    expect(find.text('Distrito atendido: Cajamarca'), findsOneWidget);
    expect(find.byKey(const Key('destination-note-missing')), findsOneWidget);
    expect(find.text('Describir el destino'), findsOneWidget);
    // El aviso de la campaña activa ya no aplica.
    expect(find.textContaining('se publicará un resumen'), findsNothing);
  });

  testWidgets('un tercero ve el resumen con el destino pero no lo edita', (
    tester,
  ) async {
    final closed = _campaign(
      status: CampaignStatus.closed,
      organizationId: 'otra-organizacion',
      destinationNote: 'Se entregó a familias del caserío.',
      summaryNotifiedAt: DateTime.utc(2026, 10, 1),
    );
    await tester.pumpWidget(
      _host(
        child: CampaignDetailPage(initial: closed),
        detail: closed,
        access: const CampaignAccess(
          role: CampaignAccess.userRole,
          organizationName: 'Persona',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _scrollToEnd(tester);

    expect(find.text('Se entregó a familias del caserío.'), findsOneWidget);
    expect(find.byKey(const Key('edit-destination-button')), findsNothing);
  });

  testWidgets('una campaña activa no muestra el resumen', (tester) async {
    final active = _campaign();
    await tester.pumpWidget(
      _host(
        child: CampaignDetailPage(initial: active),
        detail: active,
        access: const CampaignAccess(
          role: CampaignAccess.userRole,
          organizationName: 'Persona',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _scrollToEnd(tester);

    expect(find.text('Resumen de cierre'), findsNothing);
    expect(find.textContaining('se publicará un resumen'), findsOneWidget);
  });

  testWidgets('el progreso muestra sobreaporte y limita la barra a 100 %', (
    tester,
  ) async {
    final campaign = _campaign(required: 10, contributed: 14);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: CampaignProgress(campaign: campaign),
          ),
        ),
      ),
    );
    expect(find.text('140 %'), findsOneWidget);
    final indicator = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('campaign-progress-indicator')),
    );
    expect(indicator.value, 1);
  });

  testWidgets('la tarjeta de aporte pendiente se acota sin ancho infinito', (
    tester,
  ) async {
    final contribution = Contribution(
      id: 'aporte-id',
      campaignId: 'campaign-id',
      campaignTitle: 'Abrigo para Cajamarca',
      organizationId: _uid,
      needId: 'ropa',
      needName: 'Ropa',
      quantity: 3,
      contributorId: 'vecina',
      contributorName: 'Ana',
      status: ContributionStatus.pending,
      createdAt: DateTime.utc(2026, 10, 1),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        home: Scaffold(
          body: PendingContributionCard(
            contribution: contribution,
            onConfirm: () {},
            onReject: () {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Confirmar'), findsOneWidget);
    expect(find.text('Rechazar'), findsOneWidget);
  });
}
