import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/local_preferences.dart';

final darkModeProvider = NotifierProvider<DarkModeNotifier, bool>(
  DarkModeNotifier.new,
);

/// El modo oscuro es una preferencia de presentación, no un dato de la cuenta:
/// viaja en preferencias locales y se lee de forma síncrona al arrancar para
/// que la app no parpadee en claro antes de pintar en oscuro.
class DarkModeNotifier extends Notifier<bool> {
  static const _key = 'dark_mode';

  @override
  bool build() {
    return ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;
  }

  Future<void> setDark(bool value) async {
    if (state == value) return;
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_key, value);
  }

  Future<void> toggle() => setDark(!state);
}
