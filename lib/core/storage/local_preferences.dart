import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Instancia única de preferencias locales. Se inyecta en `main.dart` con
/// `overrideWithValue` tras cargarla, así los notificadores la leen de forma
/// síncrona y las pruebas la reemplazan por una en memoria.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider debe sobrescribirse en ProviderScope.',
  ),
);
