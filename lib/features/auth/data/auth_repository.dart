import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../shared/domain/person_name.dart';
import '../domain/app_user.dart';
import 'auth_exception.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(FirebaseAuth.instance, FirebaseFirestore.instance);
});

class AuthRepository {
  AuthRepository(this._auth, this._firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleInitialized = false;

  /// Emite el usuario autenticado (o `null`) y reacciona a cada cambio de
  /// sesión, incluida la restauración de la sesión al abrir la app.
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().map(_fromFirebaseOrNull);
  }

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user!;
      await _ensureUserDocuments(user);
      return AppUser.fromFirebase(user);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(friendlyAuthError(error));
    }
  }

  Future<AppUser> signUp({
    required String firstNames,
    required String lastNames,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user!;
      final names = PersonName(
        firstNames: firstNames.trim(),
        lastNames: lastNames.trim(),
      );
      await user.updateDisplayName(names.full);
      await _createUserDocuments(user, names: names);
      return AppUser.fromFirebase(user);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(friendlyAuthError(error));
    }
  }

  Future<AppUser> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();
      final googleAccount = await _googleSignIn.authenticate();
      final credential = GoogleAuthProvider.credential(
        idToken: googleAccount.authentication.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      final user = result.user!;

      // Primer acceso con Google: crea los documentos del usuario (D07).
      // Si el correo ya existe, la sesión se inicia sobre la cuenta existente.
      await _ensureUserDocuments(user);
      return AppUser.fromFirebase(user);
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(friendlyAuthError(error));
    } on GoogleSignInException catch (error) {
      throw AuthFailure(friendlyGoogleSignInError(error));
    } catch (error) {
      throw AuthFailure(friendlyAuthError(error));
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (_googleInitialized) {
      await _googleSignIn.signOut();
    }
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await _googleSignIn.initialize();
    _googleInitialized = true;
  }

  AppUser? _fromFirebaseOrNull(User? user) {
    return user == null ? null : AppUser.fromFirebase(user);
  }

  /// Crea `usuarios/{uid}` y `perfiles/{uid}` en una sola operación (D07).
  Future<void> _createUserDocuments(
    User user, {
    required PersonName names,
  }) async {
    final batch = _firestore.batch();
    batch.set(_firestore.collection('usuarios').doc(user.uid), {
      ...names.toUserFields(),
      'correo': user.email ?? '',
      'rol': 'usuario',
    });
    batch.set(_firestore.collection('perfiles').doc(user.uid), {
      'nombreCorto': names.short,
      'distrito': '',
      'fechaIngreso': FieldValue.serverTimestamp(),
      'contadores': {'donaciones': 0, 'intercambios': 0, 'voluntariados': 0},
    });
    await batch.commit();
  }

  /// Garantiza que existan los documentos del usuario, p. ej. al iniciar sesión
  /// con una cuenta creada por otra vía. Los errores se ignoran para no
  /// bloquear la sesión por un contratiempo puntual de Firestore.
  Future<void> _ensureUserDocuments(User user) async {
    try {
      final doc = await _firestore.collection('usuarios').doc(user.uid).get();
      if (doc.exists) return;
      // Google solo entrega el nombre en una cadena; el usuario lo corrige
      // desde Editar perfil si la separación no acertó.
      await _createUserDocuments(
        user,
        names: PersonName.split(user.displayName ?? ''),
      );
    } catch (_) {
      // La sesión ya quedó iniciada; los documentos se reparan en el próximo
      // inicio de sesión.
    }
  }
}
