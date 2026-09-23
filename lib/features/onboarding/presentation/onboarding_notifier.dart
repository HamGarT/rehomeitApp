import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_preferences.dart';

final onboardingCompletedProvider =
    NotifierProvider<OnboardingCompletedNotifier, bool>(
      OnboardingCompletedNotifier.new,
    );

/// El onboarding se muestra una sola vez por instalación. La marca vive en
/// preferencias locales, no en la cuenta: es una presentación de la app, no
/// un dato del usuario.
class OnboardingCompletedNotifier extends Notifier<bool> {
  static const _key = 'onboarding_completed';

  @override
  bool build() {
    return ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;
  }

  Future<void> complete() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(_key, true);
  }
}
