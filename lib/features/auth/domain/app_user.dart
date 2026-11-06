import 'package:firebase_auth/firebase_auth.dart';

/// Usuario autenticado de la aplicación.
///
/// Es la proyección que consume la UI; no depende del SDK de Firebase.
class AppUser {
  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.needsEmailVerification = false,
  });

  final String uid;
  final String? email;
  final String? displayName;

  /// Cuenta de correo que todavía no abrió el enlace de verificación. Hasta
  /// entonces la app no pasa de la pantalla de verificación y las reglas
  /// rechazan todo salvo sus propios documentos. Google llega verificado.
  final bool needsEmailVerification;

  factory AppUser.fromFirebase(User? user) {
    if (user == null) {
      throw ArgumentError(
        'Cannot create an AppUser from a null Firebase user.',
      );
    }
    return AppUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      needsEmailVerification: !user.emailVerified,
    );
  }
}
