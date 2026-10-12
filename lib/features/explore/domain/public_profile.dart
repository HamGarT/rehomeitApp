import 'package:cloud_firestore/cloud_firestore.dart';

class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.shortName,
    required this.district,
    this.joinedAt,
    this.photoUrl,
  });

  final String id;
  final String shortName;
  final String district;
  final DateTime? joinedAt;
  final String? photoUrl;

  factory PublicProfile.fromMap(String id, Map<String, Object?> map) {
    final rawDate = map['fechaIngreso'];
    final photoUrl = map['fotoUrl'] as String?;
    return PublicProfile(
      id: id,
      shortName: map['nombreCorto'] as String? ?? 'Usuario de ReHomeIt',
      district: map['distrito'] as String? ?? '',
      joinedAt: rawDate is Timestamp ? rawDate.toDate() : null,
      photoUrl: photoUrl == null || photoUrl.isEmpty ? null : photoUrl,
    );
  }
}
