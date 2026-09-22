import 'package:firebase_auth/firebase_auth.dart';

/// Usuario autenticado de la aplicación.
///
/// Es la proyección que consume la UI; no depende del SDK de Firebase.
class AppUser {
  const AppUser({required this.uid, this.email, this.displayName});

  final String uid;
  final String? email;
  final String? displayName;

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
    );
  }
}
