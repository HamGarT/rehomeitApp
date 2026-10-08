import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

const firestoreCommitTimeout = Duration(seconds: 8);

/// Confirma un lote sin bloquear la interfaz cuando no hay red.
///
/// Firestore conserva el lote en la caché local y lo envía al recuperar la
/// conexión, así que un `commit` que no responde a tiempo no es un fallo: se
/// devuelve y la operación sigue su curso. Los demás errores se propagan para
/// que cada repositorio los traduzca a su propio mensaje.
Future<void> commitOfflineTolerant(
  WriteBatch batch, {
  Duration timeout = firestoreCommitTimeout,
}) async {
  try {
    await batch.commit().timeout(timeout);
  } on TimeoutException {
    return;
  }
}
