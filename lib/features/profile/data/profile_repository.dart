import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_errors.dart';
import '../../../shared/domain/person_name.dart';
import '../../../shared/domain/publication.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    FirebaseFirestore.instance,
    FirebaseStorage.instance,
    FirebaseAuth.instance,
  );
});

class ProfileFailure implements Exception {
  const ProfileFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lecturas y edición propias de la funcionalidad de perfil.
///
/// No se apoya en [ExploreRepository] a propósito: aquel filtra por
/// `status == publicada` porque alimenta el listado de inicio, y el perfil
/// necesita justamente las publicaciones que ya no están publicadas, con su
/// estado, para poder mostrar el recorrido completo (HU20, criterios 4 y 6).
class ProfileRepository {
  ProfileRepository(this._firestore, this._storage, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  /// Lado mayor de la foto de perfil. Se ve en círculos de hasta 64 px, así
  /// que más resolución solo costaría subida y descarga.
  static const avatarSide = 512;
  static const _avatarQuality = 80;

  /// Publicaciones de [userId] de la más reciente a la más antigua. El propio
  /// dueño las ve todas; para el perfil público ([publicOnly]) se piden solo
  /// los estados visibles, porque la regla no deja listar anuladas ni
  /// retiradas ajenas (HU14-13).
  ///
  /// Exige los índices `authorId ASC + publishedAt DESC` y `authorId ASC +
  /// status ASC + publishedAt DESC` de `firestore.indexes.json`.
  Stream<List<Publication>> watchPublicationsByAuthor(
    String userId, {
    bool publicOnly = false,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('publicaciones')
        .where('authorId', isEqualTo: userId);
    if (publicOnly) {
      query = query.where(
        'status',
        whereIn: [
          for (final status in Publication.publicStatuses) status.wireValue,
        ],
      );
    }
    return query
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

  /// Nombres y apellidos del dueño de la sesión, desde `usuarios/{uid}`, que
  /// solo él puede leer (D07). Las cuentas anteriores a la separación de
  /// campos traen solo `nombreCompleto`; se parte una vez y al guardar queda
  /// en los dos campos.
  Stream<PersonName?> watchOwnName(String userId) {
    return _firestore.collection('usuarios').doc(userId).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      if (data == null) return null;
      final firstNames = data['nombres'] as String?;
      if (firstNames == null || firstNames.isEmpty) {
        return PersonName.split(data['nombreCompleto'] as String? ?? '');
      }
      return PersonName(
        firstNames: firstNames,
        lastNames: data['apellidos'] as String? ?? '',
      );
    });
  }

  /// Guarda nombre, distrito y foto (HU20-9). Las reglas solo admiten estos
  /// campos; correo, rol, fecha de ingreso y contadores quedan como están.
  /// [district] vacío significa "sin distrito". [removePhoto] borra la actual
  /// y [newPhoto] la reemplaza; con ambos en falso o nulo no se toca.
  Future<void> updateProfile({
    required String userId,
    required PersonName names,
    required String district,
    File? newPhoto,
    bool removePhoto = false,
  }) async {
    if (names.firstNames.isEmpty) {
      throw const ProfileFailure('Escribe tu nombre.');
    }
    if (names.firstNames.length > PersonName.maxLength ||
        names.lastNames.length > PersonName.maxLength) {
      throw const ProfileFailure(
        'El nombre y los apellidos admiten hasta ${PersonName.maxLength} caracteres.',
      );
    }

    try {
      String? photoUrl;
      if (newPhoto != null) {
        photoUrl = await _uploadAvatar(userId, newPhoto);
      }

      final batch = _firestore.batch();
      batch.update(
        _firestore.collection('usuarios').doc(userId),
        names.toUserFields(),
      );
      // Sin foto nueva ni borrado, `fotoUrl` no se toca.
      final photoChange = photoUrl != null
          ? {'fotoUrl': photoUrl}
          : removePhoto
          ? {'fotoUrl': null}
          : const <String, Object?>{};
      batch.update(_firestore.collection('perfiles').doc(userId), {
        'nombreCorto': names.short,
        'distrito': district,
        ...photoChange,
      });
      await batch.commit();

      if (removePhoto && photoUrl == null) {
        // Si el borrado del archivo falla, el perfil ya no lo referencia; no
        // vale la pena fallar la edición por un archivo huérfano.
        try {
          await _avatarReference(userId).delete();
        } on FirebaseException catch (_) {}
      }
      // El nombre completo también vive en Auth, de donde lo lee la cabecera
      // del perfil propio.
      await _auth.currentUser?.updateDisplayName(names.full);
    } on FirebaseException catch (error) {
      throw ProfileFailure(_friendlyMessage(error));
    }
  }

  Reference _avatarReference(String userId) =>
      _storage.ref('perfiles/$userId/avatar.jpg');

  /// Siempre JPEG y de lado acotado: es lo que exige `storage.rules` y basta
  /// para un avatar. Si la compresión no está disponible se suben los bytes
  /// originales, que con `image_picker` ya vienen en JPEG.
  Future<String> _uploadAvatar(String userId, File photo) async {
    var bytes = await FlutterImageCompress.compressWithFile(
      photo.path,
      minWidth: avatarSide,
      minHeight: avatarSide,
      quality: _avatarQuality,
      format: CompressFormat.jpeg,
    );
    bytes ??= await photo.readAsBytes();
    final reference = _avatarReference(userId);
    await reference.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return reference.getDownloadURL();
  }

  String _friendlyMessage(FirebaseException error) {
    if (isOfflineFirebaseError(error)) {
      return 'Se requiere conexión a internet para guardar los cambios.';
    }
    if (isPermissionFirebaseError(error)) {
      return 'No se pudo guardar el perfil. Revisa los datos e inténtalo otra vez.';
    }
    return 'No se pudo guardar el perfil. Inténtalo otra vez.';
  }
}
