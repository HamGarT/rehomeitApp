import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pushNotificationsProvider = Provider<PushNotifications>((ref) {
  final service = PushNotifications(
    FirebaseMessaging.instance,
    FirebaseFirestore.instance,
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Registro del dispositivo para los avisos con la app cerrada (D22). El envío
/// lo hace el servidor al crearse un documento de `notificaciones` o una
/// publicación; aquí solo se pide el permiso y se guarda el token.
class PushNotifications {
  PushNotifications(this._messaging, this._firestore);

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  /// Sin red la baja del token no termina nunca; cerrar sesión no espera más.
  static const _unregisterTimeout = Duration(seconds: 4);

  static const messageType = 'nuevo_mensaje';

  String? _userId;
  String? _token;
  StreamSubscription<String>? _tokenRefresh;

  // iOS exige una clave de APNs que el proyecto no tiene configurada y web
  // necesita un service worker; hasta entonces el registro es solo de Android.
  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  CollectionReference<Map<String, dynamic>> get _devices =>
      _firestore.collection('dispositivos');

  /// Tipo del aviso con que la persona abrió la app, si la abrió desde uno.
  Future<String?> initialType() async {
    if (!_supported) return null;
    return _typeOf(await _messaging.getInitialMessage());
  }

  /// Tipos de los avisos que la persona toca con la app en segundo plano.
  Stream<String> get openedTypes => _supported
      ? FirebaseMessaging.onMessageOpenedApp
            .map(_typeOf)
            .where((type) => type != null)
            .cast<String>()
      : const Stream.empty();

  Future<void> register(String userId) async {
    if (!_supported) return;
    _userId = userId;
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus != AuthorizationStatus.authorized) return;
    _tokenRefresh ??= _messaging.onTokenRefresh.listen(
      (token) => _save(token).catchError((Object _) {}),
    );
    final token = await _messaging.getToken();
    if (token != null) await _save(token);
  }

  /// Debe llamarse antes de cerrar la sesión: la regla solo deja borrar el
  /// token a la cuenta que lo registró. Si no llega a borrarse, el siguiente
  /// inicio de sesión en este teléfono lo reasigna, porque el id del documento
  /// es el propio token.
  Future<void> unregister() async {
    if (!_supported) return;
    final token = _token ?? await _messaging.getToken();
    _userId = null;
    _token = null;
    if (token == null) return;
    await _devices.doc(token).delete().timeout(_unregisterTimeout);
  }

  void dispose() => _tokenRefresh?.cancel();

  Future<void> _save(String token) async {
    final userId = _userId;
    if (userId == null) return;
    final previous = _token;
    _token = token;
    await _devices.doc(token).set({
      'uid': userId,
      'platform': 'android',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (previous != null && previous != token) {
      await _devices.doc(previous).delete();
    }
  }

  static String? _typeOf(RemoteMessage? message) {
    final type = message?.data['type'];
    return type is String && type.isNotEmpty ? type : null;
  }
}
