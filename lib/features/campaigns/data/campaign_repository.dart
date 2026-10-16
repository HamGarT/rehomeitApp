import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_errors.dart';
import '../../../core/firebase/firestore_commit.dart';
import '../../../core/utils/image_mime_type.dart';
import '../domain/campaign.dart';
import '../domain/campaign_draft.dart';

final campaignRepositoryProvider = Provider<CampaignRepository>((ref) {
  return CampaignRepository(
    FirebaseFirestore.instance,
    FirebaseStorage.instance,
  );
});

class CampaignRepository {
  CampaignRepository(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _campaigns =>
      _firestore.collection('campanias');

  Stream<CampaignAccess> watchAccess(String userId) {
    return _firestore.collection('usuarios').doc(userId).snapshots().map((doc) {
      final data = doc.data();
      return CampaignAccess(
        role: data?['rol'] as String? ?? CampaignAccess.userRole,
        organizationName: data?['nombreCompleto'] as String? ?? '',
      );
    });
  }

  /// Una sola consulta mantiene el listado compatible con la caché local.
  /// La separación activa/cerrada es efectiva y se hace en el cliente, porque
  /// un documento `active` cuya fecha venció pertenece a Cerradas aunque nadie
  /// haya persistido todavía esa transición.
  Stream<List<Campaign>> watchCampaigns() {
    return _campaigns
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => Campaign.fromMap(
                  doc.id,
                  doc.data(),
                  hasPendingWrites: doc.metadata.hasPendingWrites,
                ),
              )
              .toList(growable: false),
        );
  }

  Stream<Campaign?> watchCampaign(String campaignId) {
    return _campaigns
        .doc(campaignId)
        .snapshots(includeMetadataChanges: true)
        .map(
          (doc) => doc.data() == null
              ? null
              : Campaign.fromMap(
                  doc.id,
                  doc.data()!,
                  hasPendingWrites: doc.metadata.hasPendingWrites,
                ),
        );
  }

  /// Consulta preparada para la administración propia de HU15. No usa
  /// `orderBy`, de modo que el filtro simple no necesita un índice compuesto.
  Stream<List<Campaign>> watchOwnCampaigns(String organizationId) {
    return _campaigns
        .where('organizationId', isEqualTo: organizationId)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => Campaign.fromMap(
                  doc.id,
                  doc.data(),
                  hasPendingWrites: doc.metadata.hasPendingWrites,
                ),
              )
              .toList(growable: false),
        );
  }

  Future<String> create({
    required CampaignDraft draft,
    required String organizationId,
    required String organizationName,
  }) async {
    final now = DateTime.now().toUtc();
    if (organizationId.isEmpty ||
        organizationName.trim().isEmpty ||
        !draft.isValidAt(now)) {
      throw const CampaignFailure(
        'Revisa los datos obligatorios antes de crear la campaña.',
      );
    }

    final document = _campaigns.doc();
    Reference? uploaded;
    try {
      String? imageUrl;
      String? imagePath;
      if (draft.newImage case final image?) {
        uploaded = _imageReference(document.id, organizationId, image);
        await uploaded.putFile(
          image,
          SettableMetadata(contentType: imageMimeType(image.path)),
        );
        imageUrl = await uploaded.getDownloadURL();
        imagePath = uploaded.fullPath;
      }

      final campaign = Campaign(
        id: document.id,
        organizationId: organizationId,
        organizationName: organizationName.trim(),
        title: draft.title.trim(),
        description: draft.description.trim(),
        district: draft.district.trim(),
        closeAt: draft.closeAt!.toUtc(),
        imageUrl: imageUrl,
        imageStoragePath: imagePath,
        collectionPoint: CollectionPoint(
          name: draft.collectionPointName.trim(),
          address: draft.collectionPointAddress.trim(),
          openingHours: draft.collectionPointOpeningHours.trim(),
        ),
        needs: draft.needs.map((need) => need.toNeed()).toList(growable: false),
        status: CampaignStatus.active,
        createdAt: now,
        updatedAt: now,
      );
      final batch = _firestore.batch();
      batch.set(document, {
        ...campaign.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await commitOfflineTolerant(batch);
      return document.id;
    } on FirebaseException catch (error) {
      if (uploaded != null) await _deleteBestEffort(uploaded);
      throw CampaignFailure(_friendlyCampaignError(error));
    } catch (error) {
      if (uploaded != null) await _deleteBestEffort(uploaded);
      if (error is CampaignFailure) rethrow;
      throw const CampaignFailure(
        'No se pudo crear la campaña. Tus datos se conservaron para reintentar.',
      );
    }
  }

  Future<void> update({
    required Campaign campaign,
    required CampaignDraft draft,
  }) async {
    final now = DateTime.now().toUtc();
    if (!draft.isValidAt(now)) {
      throw const CampaignFailure('Revisa los datos antes de guardar.');
    }

    Reference? uploaded;
    String? imageUrl = draft.removeExistingImage
        ? null
        : draft.existingImageUrl;
    String? imagePath = draft.removeExistingImage
        ? null
        : draft.existingImageStoragePath;
    try {
      if (draft.newImage case final image?) {
        uploaded = _imageReference(campaign.id, campaign.organizationId, image);
        await uploaded.putFile(
          image,
          SettableMetadata(contentType: imageMimeType(image.path)),
        );
        imageUrl = await uploaded.getDownloadURL();
        imagePath = uploaded.fullPath;
      }

      final batch = _firestore.batch();
      batch.update(_campaigns.doc(campaign.id), {
        'title': draft.title.trim(),
        'description': draft.description.trim(),
        'district': draft.district.trim(),
        'closeAt': Timestamp.fromDate(draft.closeAt!.toUtc()),
        'imageUrl': imageUrl,
        'imageStoragePath': imagePath,
        'collectionPoint': {
          'name': draft.collectionPointName.trim(),
          'address': draft.collectionPointAddress.trim(),
          'openingHours': draft.collectionPointOpeningHours.trim(),
        },
        'needs': draft.needs.map((need) => need.toNeed().toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await commitOfflineTolerant(batch);

      final previousPath = campaign.imageStoragePath;
      if (previousPath != null && previousPath != imagePath) {
        await _deleteBestEffort(_storage.ref(previousPath));
      }
    } on FirebaseException catch (error) {
      // El formulario sigue montado y conserva campos e imagen para reintento.
      throw CampaignFailure(_friendlyCampaignError(error));
    }
  }

  /// Descripción del destino de lo recibido (HU17-6). Solo la admite la regla
  /// con la campaña cerrada; el texto se recorta a lo que la regla acepta.
  Future<void> saveDestinationNote({
    required String campaignId,
    required String note,
  }) async {
    final trimmed = note.trim();
    if (trimmed.isEmpty) {
      throw const CampaignFailure('Escribe a qué se destinó lo recibido.');
    }
    if (trimmed.length > destinationNoteMaxLength) {
      throw const CampaignFailure(
        'La descripción del destino admite hasta $destinationNoteMaxLength caracteres.',
      );
    }
    final batch = _firestore.batch();
    batch.update(_campaigns.doc(campaignId), {
      'destinationNote': trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    try {
      await commitOfflineTolerant(batch);
    } on FirebaseException catch (error) {
      throw CampaignFailure(_friendlyCampaignError(error));
    }
  }

  static const destinationNoteMaxLength = 1000;

  Future<void> closeEarly({
    required String campaignId,
    required String closedBy,
    required String reason,
  }) async {
    try {
      await _campaigns.doc(campaignId).update({
        'status': CampaignStatus.closed.wireValue,
        'updatedAt': FieldValue.serverTimestamp(),
        'closedAt': FieldValue.serverTimestamp(),
        'closedBy': closedBy,
        'closureReason': reason,
      });
    } on FirebaseException catch (error) {
      throw CampaignFailure(_friendlyCampaignError(error));
    }
  }

  Reference _imageReference(
    String campaignId,
    String organizationId,
    File image,
  ) {
    final extension = switch (image.path.split('.').last.toLowerCase()) {
      'jpg' ||
      'jpeg' ||
      'png' ||
      'webp' ||
      'heic' ||
      'heif' => image.path.split('.').last.toLowerCase(),
      _ => 'jpg',
    };
    return _storage.ref(
      'campanias/$campaignId/$organizationId/cover.$extension',
    );
  }

  Future<void> _deleteBestEffort(Reference reference) async {
    try {
      await reference.delete();
    } on FirebaseException catch (_) {}
  }
}

class CampaignFailure implements Exception {
  const CampaignFailure(this.message);

  final String message;
}

String _friendlyCampaignError(FirebaseException error) {
  if (isOfflineFirebaseError(error)) {
    return 'La imagen necesita conexión. El formulario se conservó para que puedas reintentar.';
  }
  if (isPermissionFirebaseError(error)) {
    return 'Tu cuenta no tiene permiso para realizar esta operación.';
  }
  return 'No se pudo guardar la campaña. Inténtalo nuevamente.';
}
