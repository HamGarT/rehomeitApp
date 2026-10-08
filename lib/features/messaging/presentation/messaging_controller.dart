import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/messaging_repository.dart';
import '../domain/conversation.dart';

final userConversationsProvider =
    StreamProvider.family<List<Conversation>, String>((ref, userId) {
      return ref.watch(messagingRepositoryProvider).watchConversations(userId);
    });

final conversationMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, conversationId) {
      return ref
          .watch(messagingRepositoryProvider)
          .watchMessages(conversationId);
    });

final messagingControllerProvider =
    NotifierProvider<MessagingController, AsyncValue<void>>(
      MessagingController.new,
    );

class MessagingController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> send(Conversation conversation, String body) async {
    if (state.isLoading) return 'Espera a que termine el envío actual.';
    final userId = ref.read(authStateProvider).value?.uid;
    if (userId == null) return 'Inicia sesión para enviar mensajes.';
    state = const AsyncLoading();
    try {
      await ref
          .read(messagingRepositoryProvider)
          .sendMessage(
            conversation: conversation,
            senderId: userId,
            body: body,
          );
      state = const AsyncData(null);
      return null;
    } on MessagingFailure catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return error.message;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return 'No se pudo enviar el mensaje.';
    }
  }
}
