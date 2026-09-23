import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_exception.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

/// Estado reactivo de la sesión. Emite el usuario autenticado (o `null`) y se
/// actualiza solo ante cambios de sesión. Impulsa el enrutamiento raíz.
final authStateProvider = StreamProvider<AppUser?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges();
});

/// Controla las acciones de autenticación (login, registro, Google). La UI
/// observa su estado para mostrar el progreso y los errores amigables.
final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<AppUser?>>(AuthController.new);

class AuthController extends Notifier<AsyncValue<AppUser?>> {
  @override
  AsyncValue<AppUser?> build() => const AsyncData(null);

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  bool get isSubmitting => state.isLoading;

  Future<String?> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _run(
      () => _repository.signInWithEmail(email: email, password: password),
    );
  }

  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
  }) {
    return _run(
      () => _repository.signUp(name: name, email: email, password: password),
    );
  }

  Future<String?> signInWithGoogle() =>
      _run(() => _repository.signInWithGoogle());

  /// No toca [state]: la pantalla de acceso lo lee para sus botones y
  /// aparece antes de que termine el cierre. El perfil lleva su propio
  /// indicador de progreso.
  Future<void> signOut() => _repository.signOut();

  /// Ejecuta una acción y devuelve `null` si tuvo éxito (o fue cancelada) o un
  /// mensaje amigable listo para mostrar si falló.
  Future<String?> _run(Future<AppUser> Function() action) async {
    if (state.isLoading) return null;

    state = const AsyncLoading();
    state = await AsyncValue.guard(action);

    if (!state.hasError) return null;

    final error = state.error!;
    state = const AsyncData(null);
    final message = friendlyAuthError(error);
    return message.isEmpty ? null : message;
  }
}
