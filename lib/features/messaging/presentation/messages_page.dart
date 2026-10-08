import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/publication_image.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/conversation.dart';
import 'conversation_page.dart';
import 'messaging_controller.dart';

class MessagesPage extends ConsumerWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authStateProvider).value?.uid;
    if (userId == null) {
      return const Center(child: Text('Inicia sesión para ver tus mensajes.'));
    }
    return ref
        .watch(userConversationsProvider(userId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No pudimos cargar tus conversaciones.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(userConversationsProvider(userId)),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
          data: (conversations) => conversations.isEmpty
              ? const _EmptyMessages()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: conversations.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _ConversationTile(conversation: conversations[index]),
                ),
        );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox.square(
            dimension: 58,
            child: PublicationImage(url: conversation.publicationImageUrl),
          ),
        ),
        title: Text(
          conversation.publicationTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          conversation.lastMessage.isEmpty
              ? 'Conversación iniciada'
              : conversation.lastMessage,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          _compactDate(conversation.updatedAt),
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ConversationPage(conversation: conversation),
          ),
        ),
      ),
    );
  }
}

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 52,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 12),
            Text(
              'Aún no tienes conversaciones. Puedes iniciar una desde el detalle de un bien.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _compactDate(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return '${two(local.hour)}:${two(local.minute)}';
  }
  return '${two(local.day)}/${two(local.month)}';
}
