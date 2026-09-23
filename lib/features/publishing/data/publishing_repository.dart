import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/image_mime_type.dart';
import '../../../shared/domain/publication.dart';
import '../domain/publish_draft.dart';

final publishingRepositoryProvider = Provider<PublishingRepository>((ref) {
  return PublishingRepository(
    FirebaseFirestore.instance,
    FirebaseStorage.instance,
  );
});

class PublishingRepository {
  PublishingRepository(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  Future<Publication> publish({
    required PublishDraft draft,
    required String authorId,
  }) async {
    if (draft.photos.isEmpty ||
        !draft.formCompleted ||
        !draft.modeCompleted ||
        authorId.isEmpty) {
      throw const PublishingFailure(
        'Revisa los datos obligatorios antes de publicar.',
      );
    }

    final document = _firestore.collection('publicaciones').doc();
    final uploaded = <Reference>[];

    try {
      final imageUrls = <String>[];
      for (var index = 0; index < draft.photos.length; index++) {
        final reference = _imageReference(
          authorId: authorId,
          publicationId: document.id,
          index: index,
          file: draft.photos[index],
        );
        uploaded.add(reference);
        await reference.putFile(
          draft.photos[index],
          SettableMetadata(
            contentType: imageMimeType(draft.photos[index].path),
          ),
        );
        imageUrls.add(await reference.getDownloadURL());
      }

      final publication = Publication(
        id: document.id,
        authorId: authorId,
        title: draft.title.trim(),
        category: draft.category!,
        condition: draft.condition!,
        description: draft.description.trim(),
        details: draft.details
            .map(
              (detail) => ItemDetail(
                name: detail.name.trim(),
                value: detail.value.trim(),
              ),
            )
            .where(
              (detail) => detail.name.isNotEmpty && detail.value.isNotEmpty,
            )
            .toList(growable: false),
        district: draft.district!,
        mode: draft.mode!,
        deliveryType: draft.mode == PublicationMode.donation
            ? draft.deliveryMethod
            : null,
        status: PublicationStatus.published,
        images: imageUrls,
        publishedAt: DateTime.now().toUtc(),
        statusDates: {PublicationStatus.published: DateTime.now().toUtc()},
      );

      await document.set({
        ...publication.toMap(),
        'publishedAt': FieldValue.serverTimestamp(),
        'statusDates': {
          PublicationStatus.published.wireValue: FieldValue.serverTimestamp(),
        },
      });
      return publication;
    } on FirebaseException catch (error) {
      await _deleteUploaded(uploaded);
      throw PublishingFailure(_friendlyFirebaseError(error));
    } catch (_) {
      await _deleteUploaded(uploaded);
      throw const PublishingFailure(
        'No se pudo registrar la publicación. Inténtalo nuevamente.',
      );
    }
  }

  /// Retira una publicación propia (HU03-18). La regla de Firestore solo
  /// admite el paso publicada -> anulada y únicamente sobre `status`, por lo
  /// que no se registra fecha del hito: una publicación anulada sale de la
  /// consulta pública y no tiene recorrido.
  Future<void> withdraw(String publicationId) async {
    try {
      await _firestore.collection('publicaciones').doc(publicationId).update({
        'status': PublicationStatus.cancelled.wireValue,
      });
    } on FirebaseException catch (error) {
      throw PublishingFailure(
        error.code == 'permission-denied'
            ? 'La publicación ya no se puede retirar porque tiene un compromiso asociado.'
            : _friendlyFirebaseError(error),
      );
    }
  }

  Reference _imageReference({
    required String authorId,
    required String publicationId,
    required int index,
    required File file,
  }) {
    final safeExtension = _imageExtension(file.path);
    return _storage.ref(
      'publicaciones/$authorId/$publicationId/foto_$index.$safeExtension',
    );
  }

  Future<void> _deleteUploaded(List<Reference> references) async {
    for (final reference in references) {
      try {
        await reference.delete();
      } catch (_) {
        // Limpieza de mejor esfuerzo; nunca oculta el error original.
      }
    }
  }

  String _imageExtension(String path) {
    final extension = path.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' || 'png' || 'webp' || 'heic' || 'heif' => extension,
      _ => 'jpg',
    };
  }
}

class PublishingFailure implements Exception {
  const PublishingFailure(this.message);

  final String message;
}

String _friendlyFirebaseError(FirebaseException error) {
  if (error.code == 'network-request-failed' ||
      error.code == 'retry-limit-exceeded' ||
      error.code == 'unavailable') {
    return 'Se requiere conexión a internet para subir las fotografías. Tus datos se conservaron.';
  }
  if (error.code == 'unauthenticated' || error.code == 'unauthorized') {
    return 'Tu sesión no permite publicar. Vuelve a iniciar sesión.';
  }
  return 'No se pudo registrar la publicación. Tus datos se conservaron para que puedas reintentar.';
}
