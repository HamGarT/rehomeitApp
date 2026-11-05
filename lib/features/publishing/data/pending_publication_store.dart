import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/utils/image_mime_type.dart';
import '../../../shared/domain/publication.dart';
import '../domain/publish_draft.dart';

/// Fotografía copiada al directorio de la app. La original vive en la caché
/// de `image_picker`, que el sistema puede vaciar antes de que vuelva la red.
class PendingPhoto {
  const PendingPhoto({
    required this.index,
    required this.localPath,
    required this.extension,
  });

  final int index;
  final String localPath;
  final String extension;

  String get contentType => imageMimeType(localPath);

  Map<String, Object?> toJson() => {
    'index': index,
    'localPath': localPath,
    'extension': extension,
  };

  factory PendingPhoto.fromJson(Map<String, Object?> json) => PendingPhoto(
    index: json['index'] as int? ?? 0,
    localPath: json['localPath'] as String? ?? '',
    extension: json['extension'] as String? ?? 'jpg',
  );
}

/// Publicación confirmada por la persona que aún no llegó al servidor. Lleva
/// el id definitivo: con él la ruta de cada foto y el documento son los
/// mismos en cada reintento, y por eso repetir la sincronización no duplica.
class PendingPublication {
  const PendingPublication({
    required this.publicationId,
    required this.authorId,
    required this.title,
    required this.category,
    required this.condition,
    required this.description,
    required this.details,
    required this.district,
    required this.mode,
    required this.deliveryType,
    required this.photos,
  });

  final String publicationId;
  final String authorId;
  final String title;
  final String category;
  final String condition;
  final String description;
  final List<ItemDetail> details;
  final String district;
  final PublicationMode mode;
  final DeliveryType? deliveryType;
  final List<PendingPhoto> photos;

  Map<String, Object?> toJson() => {
    'publicationId': publicationId,
    'authorId': authorId,
    'title': title,
    'category': category,
    'condition': condition,
    'description': description,
    'details': details.map((detail) => detail.toMap()).toList(),
    'district': district,
    'mode': mode.wireValue,
    'deliveryType': deliveryType?.wireValue,
    'photos': photos.map((photo) => photo.toJson()).toList(),
  };

  factory PendingPublication.fromJson(Map<String, Object?> json) {
    return PendingPublication(
      publicationId: json['publicationId'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      condition: json['condition'] as String? ?? '',
      description: json['description'] as String? ?? '',
      details: _readList(json['details']).map(ItemDetail.fromMap).toList(),
      district: json['district'] as String? ?? '',
      mode: PublicationModeWire.fromValue(json['mode'] as String?),
      deliveryType: DeliveryTypeWire.fromNullableValue(
        json['deliveryType'] as String?,
      ),
      photos: _readList(json['photos']).map(PendingPhoto.fromJson).toList(),
    );
  }

  static List<Map<String, Object?>> _readList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList();
  }
}

/// Cola en disco de publicaciones, con la misma forma que la de entregas:
/// una carpeta por publicación con su JSON y sus fotos, que se borra entera
/// cuando el servidor ya tiene el documento.
class PendingPublicationStore {
  Future<PendingPublication> save({
    required String publicationId,
    required String authorId,
    required PublishDraft draft,
  }) async {
    final directory = await _publicationDirectory(publicationId);
    final photos = <PendingPhoto>[];
    for (var index = 0; index < draft.photos.length; index++) {
      final extension = _extension(draft.photos[index].path);
      final persisted = File('${directory.path}/foto_$index.$extension');
      await draft.photos[index].copy(persisted.path);
      photos.add(
        PendingPhoto(
          index: index,
          localPath: persisted.path,
          extension: extension,
        ),
      );
    }
    final pending = PendingPublication(
      publicationId: publicationId,
      authorId: authorId,
      title: draft.title.trim(),
      category: draft.category ?? '',
      condition: draft.condition ?? '',
      description: draft.description.trim(),
      details: draft.details
          .map(
            (detail) => ItemDetail(
              name: detail.name.trim(),
              value: detail.value.trim(),
            ),
          )
          .where((detail) => detail.name.isNotEmpty && detail.value.isNotEmpty)
          .toList(growable: false),
      district: draft.district ?? '',
      mode: draft.mode ?? PublicationMode.donation,
      deliveryType: draft.mode == PublicationMode.donation
          ? draft.deliveryMethod
          : null,
      photos: photos,
    );
    // El JSON se escribe al final: una carpeta sin JSON es un guardado a
    // medias y `readAll` la ignora.
    await File('${directory.path}/$_descriptorName')
        .writeAsString(jsonEncode(pending.toJson()), flush: true);
    return pending;
  }

  Future<List<PendingPublication>> readAll({String? authorId}) async {
    final root = await _rootDirectory();
    final result = <PendingPublication>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final descriptor = File('${entity.path}/$_descriptorName');
      if (!await descriptor.exists()) continue;
      try {
        final decoded = jsonDecode(await descriptor.readAsString());
        if (decoded is! Map) continue;
        final pending = PendingPublication.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
        if (authorId == null || pending.authorId == authorId) {
          result.add(pending);
        }
      } catch (_) {
        // Un descriptor corrupto no debe impedir sincronizar los demás.
      }
    }
    return result;
  }

  Future<void> remove(PendingPublication pending) async {
    final directory = await _publicationDirectory(pending.publicationId);
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  static const _descriptorName = 'publication.json';

  Future<Directory> _rootDirectory() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/pending_publications');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> _publicationDirectory(String publicationId) async {
    final root = await _rootDirectory();
    final directory = Directory('${root.path}/$publicationId');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }
}

String _extension(String path) {
  final value = path.split('.').last.toLowerCase();
  return switch (value) {
    'jpg' || 'jpeg' || 'png' || 'webp' || 'heic' || 'heif' => value,
    _ => 'jpg',
  };
}
