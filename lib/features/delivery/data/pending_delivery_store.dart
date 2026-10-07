import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class PendingDelivery {
  const PendingDelivery({
    required this.publicationId,
    required this.userId,
    required this.recipientInitials,
    required this.district,
    required this.localPhotoPath,
    required this.contentType,
    required this.extension,
    required this.isDirect,
  });

  final String publicationId;
  final String userId;
  final String recipientInitials;
  final String district;
  final String localPhotoPath;
  final String contentType;
  final String extension;
  final bool isDirect;

  Map<String, Object?> toJson() => {
    'publicationId': publicationId,
    'userId': userId,
    'recipientInitials': recipientInitials,
    'district': district,
    'localPhotoPath': localPhotoPath,
    'contentType': contentType,
    'extension': extension,
    'isDirect': isDirect,
  };

  factory PendingDelivery.fromJson(Map<String, Object?> json) {
    return PendingDelivery(
      publicationId: json['publicationId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      recipientInitials: json['recipientInitials'] as String? ?? '',
      district: json['district'] as String? ?? '',
      localPhotoPath: json['localPhotoPath'] as String? ?? '',
      contentType: json['contentType'] as String? ?? 'image/jpeg',
      extension: json['extension'] as String? ?? 'jpg',
      isDirect: json['isDirect'] as bool? ?? false,
    );
  }
}

class PendingDeliveryStore {
  Future<PendingDelivery> save({
    required String publicationId,
    required String userId,
    required String recipientInitials,
    required String district,
    required File photo,
    required bool isDirect,
  }) async {
    final directory = await _directory();
    final extension = _extension(photo.path);
    final persistedPhoto = File('${directory.path}/$publicationId.$extension');
    await photo.copy(persistedPhoto.path);
    final pending = PendingDelivery(
      publicationId: publicationId,
      userId: userId,
      recipientInitials: recipientInitials,
      district: district,
      localPhotoPath: persistedPhoto.path,
      contentType: _contentType(extension),
      extension: extension,
      isDirect: isDirect,
    );
    await File('${directory.path}/$publicationId.json')
        .writeAsString(jsonEncode(pending.toJson()), flush: true);
    return pending;
  }

  Future<List<PendingDelivery>> readAll({String? userId}) async {
    final directory = await _directory();
    final result = <PendingDelivery>[];
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final decoded = jsonDecode(await entity.readAsString());
        if (decoded is! Map) continue;
        final pending = PendingDelivery.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
        if (userId == null || pending.userId == userId) result.add(pending);
      } catch (_) {
        // Un archivo incompleto no debe impedir sincronizar los demás.
      }
    }
    return result;
  }

  Future<void> remove(PendingDelivery pending) async {
    final directory = await _directory();
    for (final path in [
      pending.localPhotoPath,
      '${directory.path}/${pending.publicationId}.json',
    ]) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  Future<Directory> _directory() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/pending_deliveries');
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

String _contentType(String extension) => switch (extension) {
  'png' => 'image/png',
  'webp' => 'image/webp',
  'heic' => 'image/heic',
  'heif' => 'image/heif',
  _ => 'image/jpeg',
};
