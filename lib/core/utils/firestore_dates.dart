import 'package:cloud_firestore/cloud_firestore.dart';

/// Lee una fecha tal como llega de Firestore. Un documento escrito con
/// `serverTimestamp()` y leído desde la caché local antes de sincronizar trae
/// `null`, así que el resultado es opcional y el modelo decide el respaldo.
DateTime? readFirestoreDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
