import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/domain/publication.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(FirebaseFirestore.instance);
});

/// Lecturas propias de la funcionalidad de perfil.
///
/// No se apoya en [ExploreRepository] a propósito: aquel filtra por
/// `status == publicada` porque alimenta el listado deExplore, y el perfil
/// necesita justamente las publicaciones que ya no están publicadas, con su
/// estado, para poder mostrar el recorrido completo (HU20, criterios 4 y 6).
class ProfileRepository {
  ProfileRepository(this._firestore);

  final FirebaseFirestore _firestore;

  /// Todas las publicaciones de [userId], en cualquier estado y de la más
  /// reciente a la más antigua.
  ///
  /// Exige el índice compuesto `authorId ASC + publishedAt DESC` declarado en
  /// `firestore.indexes.json`.
  Stream<List<Publication>> watchPublicationsByAuthor(String userId) {
    return _firestore
        .collection('publicaciones')
        .where('authorId', isEqualTo: userId)
        .orderBy('publishedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Publication.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  /// Publicaciones ajenas en las que [userId] es o fue el voluntario, en
  /// cualquier estado. Alimentan los contadores de entregas y el impacto: una
  /// entrega la registra el voluntario, y es a él a quien el donante se la
  /// confirma (HU20, criterios 3 y 6).
  ///
  /// Sin `orderBy`: el perfil solo cuenta, no lista, y así basta el índice
  /// simple de `volunteerId`. Se diferencia de `watchCommitments`, que filtra
  /// los compromisos vivos para la sección "Mis compromisos de recojo".
  Stream<List<Publication>> watchPublicationsAsVolunteer(String userId) {
    return _firestore
        .collection('publicaciones')
        .where('volunteerId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Publication.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }
}
