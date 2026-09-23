import 'package:cloud_firestore/cloud_firestore.dart';

class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.shortName,
    required this.district,
    this.joinedAt,
  });

  final String id;
  final String shortName;
  final String district;
  final DateTime? joinedAt;

  factory PublicProfile.fromMap(String id, Map<String, Object?> map) {
    final rawDate = map['fechaIngreso'];
    return PublicProfile(
      id: id,
      shortName: map['nombreCorto'] as String? ?? 'Usuario de ReHomeIt',
      district: map['distrito'] as String? ?? '',
      joinedAt: rawDate is Timestamp ? rawDate.toDate() : null,
    );
  }
}
