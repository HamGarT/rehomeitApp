import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/widgets/auth_widgets.dart';
import '../features/onboarding/presentation/onboarding_notifier.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import 'home_shell.dart';
import 'theme.dart';

class RehomeitApp extends ConsumerWidget {
  const RehomeitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingCompletedProvider);
    final auth = ref.watch(authStateProvider);

    final Widget child;
    if (!onboarding) {
      child = const OnboardingPage();
    } else if (auth.isLoading) {
      child = const _SessionLoadingScreen();
    } else {
      final user = auth.value;
      child = user == null ? const LoginPage() : const HomeShell();
    }

    return MaterialApp(
      title: 'ReHomeIt',
      theme: buildAppTheme(),
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: child,
      ),
    );
  }
}

/// Pantalla breve mientras se restaura la sesión al abrir la app.
class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: authBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AuthMascot(size: 120),
            SizedBox(height: 22),
            Text(
              'ReHomeIt',
              style: TextStyle(
                fontFamily: 'FreckleFace',
                fontSize: 40,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 18),
            SizedBox.square(
              dimension: 26,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
