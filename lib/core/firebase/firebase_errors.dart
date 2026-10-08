import 'package:firebase_core/firebase_core.dart';

// `unknown` entra porque Storage lo devuelve al cortarse la red a mitad de una
// subida; `retry-limit-exceeded` es su agotamiento de reintentos.
const _offlineCodes = {
  'unavailable',
  'network-request-failed',
  'retry-limit-exceeded',
  'unknown',
};

const _permissionCodes = {'permission-denied', 'unauthenticated', 'unauthorized'};

/// La operación falló por falta de conexión y puede reintentarse tal cual.
bool isOfflineFirebaseError(FirebaseException error) =>
    _offlineCodes.contains(error.code);

/// Firestore o Storage rechazaron la operación por reglas o por sesión.
bool isPermissionFirebaseError(FirebaseException error) =>
    _permissionCodes.contains(error.code);
