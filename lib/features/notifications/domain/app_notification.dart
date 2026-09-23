import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String message;
  final DateTime createdAt;

  factory AppNotification.fromMap(String id, Map<String, Object?> map) {
    final rawDate = map['createdAt'];
    return AppNotification(
      id: id,
      message: map['message'] as String? ?? 'Tienes una nueva notificación.',
      createdAt: rawDate is Timestamp
          ? rawDate.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
