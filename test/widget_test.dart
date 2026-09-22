import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rehomeitapp/app/app.dart';
import 'package:rehomeitapp/features/auth/domain/app_user.dart';
import 'package:rehomeitapp/features/auth/presentation/auth_controller.dart';

ProviderScope _buildApp({AppUser? user}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream<AppUser?>.value(user)),
    ],
    child: const RehomeitApp(),
  );
}

void main() {
  testWidgets('shows onboarding on launch', (WidgetTester tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    expect(
      find.text('No dejes que se desperdicien las cosas buenas'),
      findsOneWidget,
    );
  });

  testWidgets('shows login after completing onboarding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
    await tester.pumpAndSettle();
    await tester.tap(find.text("Let's get started"));
    await tester.pumpAndSettle();
    expect(find.text('¡Hola de nuevo!'), findsOneWidget);
  });

  testWidgets('authenticated users skip login and go straight home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        user: const AppUser(uid: 'uid-1', email: 'a@b.com'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
    await tester.pumpAndSettle();
    await tester.tap(find.text("Let's get started"));
    await tester.pumpAndSettle();
    expect(find.text('Explorar'), findsOneWidget);
    expect(find.text('¡Hola de nuevo!'), findsNothing);
  });
}
