import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/domain/publication.dart';
import '../domain/conversation.dart';

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  return MessagingRepository(FirebaseFirestore.instance);
});

class MessagingRepository {
  MessagingRepository(this._firestore);

  final FirebaseFirestore _firestore;

  static String conversationId({
    required String publicationId,
    required String firstUserId,
    required String secondUserId,
  }) {
    final users = [firstUserId, secondUserId]..sort();
    return '$publicationId--${users[0]}--${users[1]}';
  }

  Stream<List<Conversation>> watchConversations(String userId) {
    return _firestore
        .collection('conversaciones')
        .where('participantIds', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Conversation.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return _firestore
        .collection('conversaciones')
        .doc(conversationId)
        .collection('mensajes')
        .orderBy('sentAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ChatMessage.fromMap(
                  doc.id,
                  doc.data(),
                  isPending: doc.metadata.hasPendingWrites,
                ),
              )
              .toList(growable: false),
        );
  }

  Future<Conversation?> getConversation(String conversationId) async {
    final snapshot = await _firestore
        .collection('conversaciones')
        .doc(conversationId)
        .get();
    return snapshot.exists
        ? Conversation.fromMap(snapshot.id, snapshot.data()!)
        : null;
  }

  Future<Conversation> startConversation({
    required Publication publication,
    required String userId,
  }) async {
    if (publication.authorId == userId) {
      throw const MessagingFailure(
        'No puedes iniciar una conversación contigo mismo.',
      );
    }
    final id = conversationId(
      publicationId: publication.id,
      firstUserId: publication.authorId,
      secondUserId: userId,
    );
    final reference = _firestore.collection('conversaciones').doc(id);

    try {
      return await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(reference);
        if (existing.exists) {
          return Conversation.fromMap(existing.id, existing.data()!);
        }
        final publicationReference = _firestore
            .collection('publicaciones')
            .doc(publication.id);
        final currentSnapshot = await transaction.get(publicationReference);
        if (!currentSnapshot.exists) {
          throw const MessagingFailure('La publicación ya no existe.');
        }
        final current = Publication.fromMap(
          currentSnapshot.id,
          currentSnapshot.data()!,
        );
        if (current.authorId != publication.authorId) {
          throw const MessagingFailure('La publicación cambió de propietario.');
        }
        final now = DateTime.now().toUtc();
        final participants = [current.authorId, userId]..sort();
        transaction.set(reference, {
          'publicationId': current.id,
          'publicationTitle': current.title,
          'publicationImageUrl': current.images.isEmpty
              ? null
              : current.images.first,
          'publicationMode': current.mode.wireValue,
          'participantIds': participants,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastSenderId': null,
          'lastMessageId': null,
        });
        return Conversation(
          id: id,
          publicationId: current.id,
          publicationTitle: current.title,
          publicationImageUrl: current.images.isEmpty
              ? null
              : current.images.first,
          publicationMode: current.mode.wireValue,
          participantIds: participants,
          createdAt: now,
          updatedAt: now,
        );
      });
    } on MessagingFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw MessagingFailure(_friendlyMessage(error));
    }
  }

  Future<void> sendMessage({
    required Conversation conversation,
    required String senderId,
    required String body,
  }) async {
    final text = body.trim();
    if (text.isEmpty) {
      throw const MessagingFailure('Escribe un mensaje antes de enviarlo.');
    }
    if (text.length > 1000) {
      throw const MessagingFailure(
        'El mensaje no puede superar 1000 caracteres.',
      );
    }
    final recipients = conversation.participantIds
        .where((id) => id != senderId)
        .toList(growable: false);
    if (recipients.isEmpty) {
      throw const MessagingFailure('No se encontró al otro participante.');
    }
    final recipientId = recipients.first;

    final conversationRef = _firestore
        .collection('conversaciones')
        .doc(conversation.id);
    final messageRef = conversationRef.collection('mensajes').doc();
    final notificationRef = _firestore
        .collection('notificaciones')
        .doc('mensaje_${messageRef.id}');
    final batch = _firestore.batch();
    batch.set(messageRef, {
      'conversationId': conversation.id,
      'publicationId': conversation.publicationId,
      'senderId': senderId,
      'body': text,
      'queuedAt': Timestamp.now(),
      'sentAt': FieldValue.serverTimestamp(),
    });
    batch.update(conversationRef, {
      'lastMessage': text,
      'lastSenderId': senderId,
      'lastMessageId': messageRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(notificationRef, {
      'recipientId': recipientId,
      'type': 'nuevo_mensaje',
      'message':
          'Tienes un nuevo mensaje sobre ${conversation.publicationTitle}.',
      'publicationId': conversation.publicationId,
      'conversationId': conversation.id,
      'messageId': messageRef.id,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });

    try {
      await batch.commit().timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // Firestore ya conservó el lote local; se enviará al recuperar conexión.
      return;
    } on FirebaseException catch (error) {
      throw MessagingFailure(_friendlyMessage(error));
    }
  }
}

class MessagingFailure implements Exception {
  const MessagingFailure(this.message);

  final String message;
}

String _friendlyMessage(FirebaseException error) {
  if (error.code == 'unavailable' || error.code == 'network-request-failed') {
    return 'Sin conexión. El mensaje quedará pendiente y se enviará automáticamente.';
  }
  if (error.code == 'permission-denied') {
    return 'Tu sesión no permite acceder a esta conversación.';
  }
  return 'No se pudo completar la operación de mensajería.';
}
