import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/firebase/firestore_commit.dart';
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
  ///
  /// La primera emisión es la sesión restaurada, y solo esa dispara la
  /// reparación de documentos (HU01-12): quien se registró con la red caída
  /// y vuelve a abrir la app no pasa por `signIn`. Las emisiones posteriores
  /// vienen de un registro o inicio de sesión en curso, que ya escriben sus
  /// documentos; repararlos a la vez haría llegar una segunda escritura como
  /// actualización y las reglas la rechazarían.
  ///
  /// Se escucha `userChanges` y no `authStateChanges` porque el primero
  /// también emite al recargar el usuario: así la pantalla de verificación
  /// de correo da paso al inicio en cuanto Auth confirma la verificación.
  Stream<AppUser?> authStateChanges() async* {
    var restoredSession = true;
    await for (final user in _auth.userChanges()) {
      if (user != null) {
        final denial = await _accountDenial(user);
        if (denial != null) {
          await _auth.signOut();
          restoredSession = false;
          yield null;
          continue;
        }
        if (restoredSession) {
          unawaited(_ensureUserDocuments(user));
        }
        unawaited(_touchActivity(user));
      }
      restoredSession = false;
      yield _fromFirebaseOrNull(user);
    }
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
      final denial = await _accountDenial(user);
      if (denial != null) {
        await signOut();
        throw AuthFailure(denial);
      }
      await _ensureUserDocuments(user);
      unawaited(_touchActivity(user));
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
      // La cuenta ya existe y la sesión está iniciada: un fallo aquí no
      // puede reportarse como registro fallido. El nombre vive en `usuarios`
      // y Auth solo lo cubre mientras llega.
      try {
        await user.updateDisplayName(names.full);
      } on FirebaseAuthException catch (_) {}
      await _createUserDocuments(user, names: names);
      // Si el envío falla la cuenta igual queda creada: la pantalla de
      // verificación ofrece reenviarlo.
      try {
        await user.sendEmailVerification();
      } on FirebaseAuthException catch (_) {}
      return AppUser.fromFirebase(user);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(friendlyAuthError(error));
    }
  }

  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(friendlyAuthError(error));
    }
  }

  /// Vuelve a leer el usuario en Auth y, si ya verificó, renueva el token de
  /// sesión: las reglas leen `email_verified` del token y el anterior sigue
  /// valiendo hasta una hora, así que sin renovarlo la primera escritura
  /// sería rechazada. La recarga hace emitir `userChanges`, que reenruta.
  Future<bool> refreshEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.reload();
      final refreshed = _auth.currentUser;
      if (refreshed == null || !refreshed.emailVerified) return false;
      await refreshed.getIdToken(true);
      return true;
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

      final denial = await _accountDenial(user);
      if (denial != null) {
        await signOut();
        throw AuthFailure(denial);
      }
      // Primer acceso con Google: crea los documentos del usuario (D07).
      // Si el correo ya existe, la sesión se inicia sobre la cuenta existente.
      await _ensureUserDocuments(user);
      unawaited(_touchActivity(user));
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
  ///
  /// Sin red el lote queda en la caché de Firestore y se envía al reconectar,
  /// también tras cerrar la app; esperar al servidor dejaría el registro
  /// girando sin fin (HU01-12).
  Future<void> _createUserDocuments(
    User user, {
    required PersonName names,
  }) async {
    final batch = _firestore.batch();
    batch.set(_firestore.collection('usuarios').doc(user.uid), {
      ...names.toUserFields(),
      'correo': user.email ?? '',
      'rol': 'usuario',
      'ultimaActividad': FieldValue.serverTimestamp(),
    });
    batch.set(_firestore.collection('perfiles').doc(user.uid), {
      'nombreCorto': names.short,
      'distrito': '',
      'fechaIngreso': FieldValue.serverTimestamp(),
      'contadores': {'donaciones': 0, 'intercambios': 0, 'voluntariados': 0},
    });
    await commitOfflineTolerant(batch);
  }

  /// Devuelve el mensaje con el que se debe impedir la sesión, o `null` si la
  /// cuenta está activa. Un fallo de lectura no bloquea el acceso: el estado
  /// volverá a comprobarse al iniciar sesión o al reabrir la app.
  Future<String?> _accountDenial(User user) async {
    try {
      final doc = await _firestore.collection('usuarios').doc(user.uid).get();
      final data = doc.data();
      final status = data?['estadoCuenta'] as String?;
      if (status != 'bloqueada' && status != 'retirada') return null;
      final reason = (data?['estadoCuentaMotivo'] as String?)?.trim();
      final action = status == 'bloqueada' ? 'bloqueada' : 'retirada';
      if (reason == null || reason.isEmpty) {
        return 'Tu cuenta fue $action. Contacta a administración para más información.';
      }
      return 'Tu cuenta fue $action. Motivo: $reason';
    } catch (_) {
      return null;
    }
  }

  /// Mantiene una referencia para que administración pueda detectar cuentas
  /// inactivas. Se ignora cualquier fallo: no debe impedir el uso de la app.
  Future<void> _touchActivity(User user) async {
    try {
      await _firestore.collection('usuarios').doc(user.uid).update({
        'ultimaActividad': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Garantiza que existan los documentos del usuario, p. ej. al iniciar sesión
  /// con una cuenta creada por otra vía o con un registro que se quedó sin
  /// red. Los errores se ignoran para no bloquear la sesión por un
  /// contratiempo puntual de Firestore.
  Future<void> _ensureUserDocuments(User user) async {
    try {
      // Un lote del registro aún en cola ya se ve aquí como existente, así
      // que no se duplica.
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
