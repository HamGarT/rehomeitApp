import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/person_name.dart';

/// Nombre corto elegido para un perfil y si hay que escribir su reserva: no
/// hace falta cuando la persona ya la tenía.
typedef ShortNameChoice = ({String shortName, bool needsReservation});

/// Consulta quién tiene reservado un nombre corto, o `null` si está libre.
typedef ShortNameOwnerLookup = Future<String?> Function(String shortName);

/// El primer nombre corto de [names] que está libre o ya es de [userId].
/// [current] es el que la persona usa hoy: si sigue siendo válido para su
/// nombre se conserva, para que editar el distrito no se lo cambie.
Future<ShortNameChoice> chooseShortName(
  PersonName names,
  String userId, {
  required ShortNameOwnerLookup ownerOf,
  String? current,
}) async {
  final candidates = names.shortCandidates;
  final ordered = current != null && candidates.contains(current)
      ? [current, ...candidates.where((candidate) => candidate != current)]
      : candidates;
  for (final candidate in ordered) {
    final owner = await ownerOf(candidate);
    if (owner == null) return (shortName: candidate, needsReservation: true);
    if (owner == userId) return (shortName: candidate, needsReservation: false);
  }
  throw StateError('No quedan nombres cortos libres para "${names.short}".');
}

/// Reservas de nombres cortos en `nombresCortos/{clave}` (D07). Las reglas
/// exigen que el perfil y su reserva vayan en el mismo lote, así que este
/// registro solo elige el nombre y prepara las escrituras; confirmar el lote
/// es de cada repositorio.
class ShortNameRegistry {
  ShortNameRegistry(this._firestore);

  final FirebaseFirestore _firestore;

  static const _lookupTimeout = Duration(seconds: 8);

  DocumentReference<Map<String, dynamic>> reservation(String shortName) =>
      _firestore
          .collection('nombresCortos')
          .doc(PersonName.shortNameKey(shortName));

  /// Elige con [chooseShortName] consultando las reservas en el servidor.
  ///
  /// Lanza si no hay conexión: una reserva decidida con datos de caché podría
  /// pisar la de otra persona y el lote entero sería rechazado.
  Future<ShortNameChoice> choose(
    PersonName names,
    String userId, {
    String? current,
  }) => chooseShortName(names, userId, ownerOf: _ownerOf, current: current);

  /// Agrega a [batch] la reserva de [choice] y la liberación de [previous],
  /// el nombre que el perfil deja de usar.
  Future<void> stage(
    WriteBatch batch, {
    required String userId,
    required ShortNameChoice choice,
    String? previous,
  }) async {
    if (choice.needsReservation) {
      batch.set(reservation(choice.shortName), {'uid': userId});
    }
    if (previous == null ||
        PersonName.shortNameKey(previous) ==
            PersonName.shortNameKey(choice.shortName)) {
      return;
    }
    // Un perfil anterior a las reservas no tiene nada que liberar, y borrar
    // un documento ajeno o inexistente haría rechazar el lote.
    if (await _ownerOf(previous) == userId) {
      batch.delete(reservation(previous));
    }
  }

  Future<String?> _ownerOf(String shortName) async {
    final snapshot = await reservation(shortName)
        .get(const GetOptions(source: Source.server))
        .timeout(_lookupTimeout);
    return snapshot.data()?['uid'] as String?;
  }
}
