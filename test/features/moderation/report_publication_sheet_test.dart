import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rehomeitapp/app/theme.dart';
import 'package:rehomeitapp/features/auth/domain/app_user.dart';
import 'package:rehomeitapp/features/auth/presentation/auth_controller.dart';
import 'package:rehomeitapp/features/moderation/domain/publication_report.dart';
import 'package:rehomeitapp/features/moderation/presentation/report_controller.dart';
import 'package:rehomeitapp/features/moderation/presentation/report_publication_sheet.dart';
import 'package:rehomeitapp/shared/domain/publication.dart';

typedef ReportCall = ({
  String reporterId,
  ReportReason reason,
  String? comment,
});

/// Controlador que anota lo que la hoja le pidió y devuelve el fallo que se le
/// configure. Evita Firestore: el repositorio es lo que se prueba aparte.
class _FakeReportController extends ReportController {
  _FakeReportController(this.calls);

  final List<ReportCall> calls;

  /// Mensaje con el que "falla" el envío; `null` responde con éxito.
  String? failure;

  @override
  AsyncValue<void> build() => const AsyncData(null);

  @override
  Future<String?> report({
    required Publication publication,
    required String reporterId,
    required ReportReason reason,
    String? comment,
  }) async {
    state = const AsyncLoading();
    calls.add((reporterId: reporterId, reason: reason, comment: comment));
    state = const AsyncData(null);
    return failure;
  }
}

final _publication = Publication(
  id: 'publication',
  authorId: 'otra-persona',
  title: 'Mesa de madera',
  category: 'Hogar',
  condition: 'Usado',
  description: 'En buen estado.',
  details: const [],
  district: 'Cajamarca',
  mode: PublicationMode.donation,
  status: PublicationStatus.published,
  images: const ['https://example.test/1.jpg'],
  publishedAt: DateTime.utc(2026, 9, 20),
);

/// Monta la hoja desde el mismo punto de entrada que usan el feed y el
/// detalle, para que la prueba cubra también la confirmación.
Widget _host(
  List<ReportCall> calls, {
  String? userId = 'reporter',
  String? failure,
}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          userId == null ? null : AppUser(uid: userId, email: 'a@b.com'),
        ),
      ),
      reportControllerProvider.overrideWith(() {
        final controller = _FakeReportController(calls)..failure = failure;
        return controller;
      }),
    ],
    child: MaterialApp(
      theme: buildAppTheme(brightness: Brightness.light),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () =>
                  reportPublication(context, publication: _publication),
              child: const Text('Reportar publicación'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  // La hoja con cinco motivos, el comentario y el botón no cabe en el
  // superficie de prueba por defecto (800x600 lógicos); se usa el tamaño de un
  // teléfono para que el botón de enviar quede dentro de la pantalla.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.tap(find.text('Reportar publicación'));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('report-submit')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('report-submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la hoja ofrece los cinco motivos y exige elegir uno', (
    tester,
  ) async {
    await tester.pumpWidget(_host([]));
    await _openSheet(tester);

    expect(find.text('Reportar publicación'), findsNWidgets(2));
    for (final reason in ReportReason.values) {
      expect(find.text(reason.label), findsOneWidget);
    }

    // Sin motivo no hay nada que enviar: el botón sale apagado en vez de
    // dejar enviar y avisar con un error después.
    final submit = tester.widget<FilledButton>(
      find.byKey(const Key('report-submit')),
    );
    expect(submit.onPressed, isNull);

    await tester.tap(find.byKey(const Key('report-reason-misleading')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('report-submit')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'enviar manda el motivo, el comentario y confirma fuera de la hoja',
    (tester) async {
      final calls = <ReportCall>[];
      await tester.pumpWidget(_host(calls));
      await _openSheet(tester);

      await tester.tap(find.byKey(const Key('report-reason-moneyRequest')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Me pidió dinero por transferencia',
      );
      await _submit(tester);

      expect(calls, hasLength(1));
      expect(calls.single.reason, ReportReason.moneyRequest);
      expect(calls.single.comment, 'Me pidió dinero por transferencia');
      expect(calls.single.reporterId, 'reporter');

      // La hoja se cierra y el aviso aparece en la pantalla de la que se salió:
      // el título del botón vuelve a estar solo y el `SnackBar` está montado.
      expect(find.text('Reporte enviado. Lo revisaremos.'), findsOneWidget);
    },
  );

  testWidgets('sin sesión no se envía nada y el motivo queda sin elegir', (
    tester,
  ) async {
    final calls = <ReportCall>[];
    await tester.pumpWidget(_host(calls, userId: null));
    await _openSheet(tester);

    await tester.tap(find.byKey(const Key('report-reason-illegalItem')));
    await tester.pumpAndSettle();
    await _submit(tester);

    expect(calls, isEmpty);
    expect(find.textContaining('Vuelve a iniciar sesión'), findsOneWidget);
    expect(find.text('Reporte enviado. Lo revisaremos.'), findsNothing);
  });

  testWidgets('un envío fallido muestra el motivo y deja la hoja abierta', (
    tester,
  ) async {
    final calls = <ReportCall>[];
    await tester.pumpWidget(
      _host(
        calls,
        failure: 'No se pudo enviar el reporte. Revisa tu conexión.',
      ),
    );
    await _openSheet(tester);

    await tester.tap(find.byKey(const Key('report-reason-other')));
    await tester.pumpAndSettle();
    await _submit(tester);

    expect(calls, hasLength(1));
    // El fallo se muestra en la hoja, no como aviso encima: el usuario puede
    // corregir el comentario y reintentar sin perder lo escrito.
    expect(find.textContaining('Revisa tu conexión'), findsOneWidget);
    expect(find.text('Reporte enviado. Lo revisaremos.'), findsNothing);
    expect(find.text('Reportar publicación'), findsNWidgets(2));
  });

  testWidgets('el comentario no pasa del límite', (tester) async {
    final calls = <ReportCall>[];
    await tester.pumpWidget(_host(calls));
    await _openSheet(tester);

    await tester.enterText(
      find.byType(TextField),
      'a' * (PublicationReport.maxCommentLength + 40),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text.length, PublicationReport.maxCommentLength);
  });
}
