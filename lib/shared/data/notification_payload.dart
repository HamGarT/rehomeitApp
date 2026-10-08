import 'package:cloud_firestore/cloud_firestore.dart';

/// Documento de la colección `notificaciones` (D01). Las claves opcionales solo
/// se incluyen cuando tienen valor porque la regla `validNotificationSchema`
/// las acota con `hasOnly` y cada tipo de notificación valida las suyas.
Map<String, Object?> notificationPayload({
  required String recipientId,
  required String type,
  required String message,
  required String publicationId,
  String? actorId,
  String? proposalId,
  String? conversationId,
  String? messageId,
}) {
  return {
    'recipientId': recipientId,
    'type': type,
    'message': message,
    'publicationId': publicationId,
    'actorId': ?actorId,
    'proposalId': ?proposalId,
    'conversationId': ?conversationId,
    'messageId': ?messageId,
    'createdAt': FieldValue.serverTimestamp(),
    'read': false,
  };
}
