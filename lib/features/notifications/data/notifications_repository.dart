import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_notification.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepository(FirebaseFirestore.instance);
});

final unreadNotificationsProvider =
    StreamProvider.family<List<AppNotification>, String>((ref, userId) {
      return ref.watch(notificationsRepositoryProvider).watchUnread(userId);
    });

class NotificationsRepository {
  NotificationsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<List<AppNotification>> watchUnread(String userId) {
    return _firestore
        .collection('notificaciones')
        .where('recipientId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppNotification.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  Future<void> markAsRead(String notificationId) {
    return _firestore.collection('notificaciones').doc(notificationId).update({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }
}
