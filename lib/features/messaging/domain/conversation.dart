import '../../../core/utils/firestore_dates.dart';
import '../../../shared/domain/publication.dart';

class Conversation {
  const Conversation({
    required this.id,
    required this.publicationId,
    required this.publicationTitle,
    required this.publicationMode,
    required this.participantIds,
    required this.createdAt,
    required this.updatedAt,
    this.publicationImageUrl,
    this.lastMessage = '',
    this.lastMessageUnreadable = false,
    this.lastSenderId,
  });

  final String id;
  final String publicationId;
  final String publicationTitle;
  final PublicationMode publicationMode;
  final String? publicationImageUrl;
  final List<String> participantIds;

  /// Vista previa del último mensaje ya descifrada; vacía si no hay mensajes.
  final String lastMessage;

  /// Hay un último mensaje pero esta compilación no pudo descifrarlo.
  final bool lastMessageUnreadable;
  final String? lastSenderId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// La otra parte de la conversación. Una conversación siempre es entre dos
  /// personas (HU09-4), así que es el participante que no es [userId].
  String? counterpartOf(String userId) {
    for (final id in participantIds) {
      if (id != userId) return id;
    }
    return null;
  }

  /// [plainText] nulo significa que el texto guardado no se pudo descifrar.
  Conversation withLastMessage(String? plainText) {
    return Conversation(
      id: id,
      publicationId: publicationId,
      publicationTitle: publicationTitle,
      publicationMode: publicationMode,
      participantIds: participantIds,
      createdAt: createdAt,
      updatedAt: updatedAt,
      publicationImageUrl: publicationImageUrl,
      lastMessage: plainText ?? '',
      lastMessageUnreadable: plainText == null,
      lastSenderId: lastSenderId,
    );
  }

  /// `lastMessage` llega tal como está guardado, cifrado; el repositorio lo
  /// descifra con [withLastMessage] antes de entregarlo.
  factory Conversation.fromMap(String id, Map<String, Object?> map) {
    final createdAt = readFirestoreDate(map['createdAt']);
    return Conversation(
      id: id,
      publicationId: map['publicationId'] as String? ?? '',
      publicationTitle: map['publicationTitle'] as String? ?? '',
      // Las reglas garantizan que coincide con la modalidad de la
      // publicación, así que un valor desconocido es un error y no un caso.
      publicationMode: PublicationModeWire.fromValue(
        map['publicationMode'] as String?,
      ),
      publicationImageUrl: map['publicationImageUrl'] as String?,
      participantIds: (map['participantIds'] as List<Object?>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      lastMessage: map['lastMessage'] as String? ?? '',
      lastSenderId: map['lastSenderId'] as String?,
      createdAt:
          createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt:
          readFirestoreDate(map['updatedAt']) ??
          createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.publicationId,
    required this.senderId,
    required this.body,
    required this.sentAt,
    required this.isPending,
    this.isUnreadable = false,
  });

  final String id;
  final String conversationId;
  final String publicationId;
  final String senderId;

  /// Texto ya descifrado; vacío cuando [isUnreadable].
  final String body;
  final DateTime sentAt;
  final bool isPending;
  final bool isUnreadable;

  /// [plainText] nulo significa que el texto guardado no se pudo descifrar.
  ChatMessage withBody(String? plainText) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      publicationId: publicationId,
      senderId: senderId,
      body: plainText ?? '',
      sentAt: sentAt,
      isPending: isPending,
      isUnreadable: plainText == null,
    );
  }

  /// `body` llega cifrado; el repositorio lo descifra con [withBody].
  factory ChatMessage.fromMap(
    String id,
    Map<String, Object?> map, {
    required bool isPending,
  }) {
    return ChatMessage(
      id: id,
      conversationId: map['conversationId'] as String? ?? '',
      publicationId: map['publicationId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      body: map['body'] as String? ?? '',
      sentAt:
          readFirestoreDate(map['sentAt']) ??
          readFirestoreDate(map['queuedAt']) ??
          DateTime.now(),
      isPending: isPending,
    );
  }
}
