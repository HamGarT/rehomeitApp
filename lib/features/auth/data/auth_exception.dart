import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Falla de autenticación ya traducida a un mensaje amigable para la UI.
class AuthFailure implements Exception {
  const AuthFailure(this.message, [this.isCancelled = false]);

  /// Operación cancelada por el usuario (p. ej. cerró el diálogo de Google).
  const AuthFailure.cancelled() : this('', true);

  /// Mensaje listo para mostrar, en blanco si la operación se canceló.
  final String message;

  /// `true` cuando la operación no es un error real, solo una cancelación.
  final bool isCancelled;
}

/// Convierte cualquier error de autenticación en un mensaje claro y amigable.
///
/// Nunca expone códigos técnicos de Firebase al usuario final.
String friendlyAuthError(Object error) {
  if (error is AuthFailure) return error.message;
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-credential':
      case 'invalid-login-credentials':
      case 'user-not-found':
      case 'wrong-password':
        return 'Correo o contraseña incorrectos.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Inténtalo más tarde.';
      case 'email-already-in-use':
        return 'Este correo ya está registrado.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 8 caracteres.';
      case 'invalid-email':
        return 'Ingresa un correo electrónico válido.';
      case 'operation-not-allowed':
        return 'Este método de acceso aún no está habilitado.';
      case 'account-exists-with-different-credential':
        return 'Este correo ya se usa con otro método de acceso.';
      case 'network-request-failed':
        return 'Se requiere conexión a internet.';
    }
  }

  final detail = error.toString().toLowerCase();
  if (detail.contains('canceled') || detail.contains('cancelled')) {
    return '';
  }
  if (detail.contains('network') || detail.contains('connection')) {
    return 'Se requiere conexión a internet.';
  }
  return 'Algo salió mal. Inténtalo de nuevo.';
}

/// Convierte un error de Google Sign-In en un mensaje amigable. Las
/// cancelaciones y las interrupciones de la UI no se reportan como errores.
String friendlyGoogleSignInError(GoogleSignInException error) {
  switch (error.code) {
    case GoogleSignInExceptionCode.canceled:
    case GoogleSignInExceptionCode.interrupted:
    case GoogleSignInExceptionCode.uiUnavailable:
      return '';
    default:
      return friendlyAuthError(error);
  }
}
