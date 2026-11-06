import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_errors.dart';
import '../../../core/firebase/firestore_commit.dart';
import '../domain/admin_user.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(FirebaseFirestore.instance);
});

class AdminFailure implements Exception {
  const AdminFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class AdminRepository {
  AdminRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('usuarios');

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _firestore.collection('perfiles');

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notificaciones');

  CollectionReference<Map<String, dynamic>> get _campaigns =>
      _firestore.collection('campanias');

  Stream<List<AdminUser>> watchUsers() {
    return _users.snapshots().asyncMap((snapshot) async {
      // El perfil aporta `fechaIngreso`, que sirve de referencia para las
      // cuentas anteriores al registro de `ultimaActividad`.
      var profiles = <String, Map<String, dynamic>>{};
      try {
        final profileSnapshot = await _profiles.get();
        profiles = {for (final doc in profileSnapshot.docs) doc.id: doc.data()};
      } catch (_) {
        // Sin perfiles la lista sigue siendo útil: se muestra "sin registro"
        // y el administrador puede revisar la cuenta manualmente.
      }

      final users = snapshot.docs
          .map(
            (doc) => AdminUser.fromUserData(
              id: doc.id,
              user: doc.data(),
              profile: profiles[doc.id],
            ),
          )
          .toList();
      users.sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );
      return users;
    });
  }

  Future<void> verifyAccount({
    required String userId,
    required String adminId,
  }) async {
    final batch = _firestore.batch();
    batch.update(_users.doc(userId), {
      'cuentaVerificadaAt': FieldValue.serverTimestamp(),
      'cuentaVerificadaPor': adminId,
    });
    batch.update(_profiles.doc(userId), {
      'cuentaVerificadaAt': FieldValue.serverTimestamp(),
      'cuentaVerificadaPor': adminId,
    });
    await _commit(batch);
  }

  Future<void> removeAccountVerification({required String userId}) async {
    final batch = _firestore.batch();
    final removal = <String, Object?>{
      'cuentaVerificadaAt': FieldValue.delete(),
      'cuentaVerificadaPor': FieldValue.delete(),
    };
    batch.update(_users.doc(userId), removal);
    batch.update(_profiles.doc(userId), removal);
    await _commit(batch);
  }

  Future<void> blockAccount({
    required String userId,
    required String adminId,
    required String reason,
  }) async {
    _rejectSelfAction(userId, adminId);
    final batch = _firestore.batch();
    batch.update(_users.doc(userId), {
      'estadoCuenta': AccountStatus.blocked.wireValue,
      'estadoCuentaMotivo': reason.trim(),
      'estadoCuentaAt': FieldValue.serverTimestamp(),
      'estadoCuentaPor': adminId,
    });
    _addAccountNotification(
      batch,
      userId: userId,
      adminId: adminId,
      type: 'cuenta_bloqueada',
      message: 'Tu cuenta fue bloqueada. Motivo: ${reason.trim()}',
    );
    await _commit(batch);
  }

  Future<void> retireAccount({
    required String userId,
    required String adminId,
    required String reason,
  }) async {
    _rejectSelfAction(userId, adminId);
    final batch = _firestore.batch();
    batch.update(_users.doc(userId), {
      'estadoCuenta': AccountStatus.retired.wireValue,
      'estadoCuentaMotivo': reason.trim(),
      'estadoCuentaAt': FieldValue.serverTimestamp(),
      'estadoCuentaPor': adminId,
    });
    _addAccountNotification(
      batch,
      userId: userId,
      adminId: adminId,
      type: 'cuenta_retirada',
      message: 'Tu cuenta fue retirada. Motivo: ${reason.trim()}',
    );
    await _commit(batch);
  }

  Future<void> reactivateAccount({
    required String userId,
    required String adminId,
  }) async {
    _rejectSelfAction(userId, adminId);
    final batch = _firestore.batch();
    batch.update(_users.doc(userId), {
      'estadoCuenta': AccountStatus.active.wireValue,
      'estadoCuentaMotivo': FieldValue.delete(),
      'estadoCuentaAt': FieldValue.serverTimestamp(),
      'estadoCuentaPor': adminId,
    });
    _addAccountNotification(
      batch,
      userId: userId,
      adminId: adminId,
      type: 'cuenta_reactivada',
      message: 'Tu cuenta fue reactivada. Ya puedes volver a iniciar sesión.',
    );
    await _commit(batch);
  }

  Future<void> notifyInactivityRetirement({
    required String userId,
    required String adminId,
  }) async {
    _rejectSelfAction(userId, adminId);
    final batch = _firestore.batch();
    batch.update(_users.doc(userId), {
      'avisoRetiroAt': FieldValue.serverTimestamp(),
    });
    _addAccountNotification(
      batch,
      userId: userId,
      adminId: adminId,
      type: 'cuenta_aviso_retiro',
      message:
          'Tu cuenta será retirada por inactividad si no vuelves a iniciar '
          'sesión. Los datos asociados se conservarán según la política de '
          'privacidad.',
    );
    await _commit(batch);
  }

  Future<void> verifyCampaign({
    required String campaignId,
    required String adminId,
  }) async {
    final batch = _firestore.batch();
    batch.update(_campaigns.doc(campaignId), {
      'verifiedAt': FieldValue.serverTimestamp(),
      'verifiedBy': adminId,
    });
    await _commit(batch);
  }

  Future<void> removeCampaignVerification({required String campaignId}) async {
    final batch = _firestore.batch();
    batch.update(_campaigns.doc(campaignId), {
      'verifiedAt': FieldValue.delete(),
      'verifiedBy': FieldValue.delete(),
    });
    await _commit(batch);
  }

  void _addAccountNotification(
    WriteBatch batch, {
    required String userId,
    required String adminId,
    required String type,
    required String message,
  }) {
    batch.set(_notifications.doc(), {
      'recipientId': userId,
      'type': type,
      'message': message,
      'actorId': adminId,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  void _rejectSelfAction(String userId, String adminId) {
    if (userId == adminId) {
      throw const AdminFailure(
        'No puedes bloquear ni retirar tu propia cuenta desde este módulo.',
      );
    }
  }

  Future<void> _commit(WriteBatch batch) async {
    try {
      await commitOfflineTolerant(batch);
    } on FirebaseException catch (error) {
      throw AdminFailure(_friendlyError(error));
    } catch (_) {
      throw const AdminFailure(
        'No se pudo completar la acción. Inténtalo nuevamente.',
      );
    }
  }
}

String _friendlyError(FirebaseException error) {
  if (isOfflineFirebaseError(error)) {
    return 'Sin conexión. La acción se enviará cuando vuelvas a estar en línea.';
  }
  if (isPermissionFirebaseError(error)) {
    return 'Las reglas rechazaron la acción. Revisa el estado de la cuenta '
        'e inténtalo de nuevo.';
  }
  return 'No se pudo completar la acción. Inténtalo nuevamente.';
}
