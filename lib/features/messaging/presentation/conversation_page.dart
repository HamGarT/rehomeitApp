import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/publication_image.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../explore/data/explore_repository.dart';
import '../../explore/presentation/publication_detail_page.dart';
import '../domain/conversation.dart';
import 'messaging_controller.dart';

class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({super.key, required this.conversation});

  final Conversation conversation;

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authStateProvider).value?.uid;
    final messages = ref.watch(
      conversationMessagesProvider(widget.conversation.id),
    );
    final sending = ref.watch(messagingControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Conversación')),
      body: SafeArea(
        child: Column(
          children: [
            _PublicationHeader(
              conversation: widget.conversation,
              onTap: _openPublication,
            ),
            const Divider(height: 1),
            Expanded(
              child: messages.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => const Center(
                  child: Text(
                    'No se pudieron cargar los mensajes. Revisa tu conexión.',
                    textAlign: TextAlign.center,
                  ),
                ),
                data: (items) => items.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Coordina aquí sin compartir teléfono ni correo electrónico.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        itemBuilder: (context, index) => _MessageBubble(
                          message: items[index],
                          isOwn: items[index].senderId == userId,
                        ),
                      ),
              ),
            ),
            _Composer(
              controller: _controller,
              enabled: userId != null && !sending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPublication() async {
    try {
      final publication = await ref
          .read(exploreRepositoryProvider)
          .watchPublication(widget.conversation.publicationId)
          .first;
      if (!mounted) return;
      if (publication == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La publicación ya no está disponible.'),
          ),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PublicationDetailPage(initial: publication),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir la publicación.')),
        );
      }
    }
  }

  Future<void> _send() async {
    final body = _controller.text;
    if (body.trim().isEmpty) return;
    final error = await ref
        .read(messagingControllerProvider.notifier)
        .send(widget.conversation, body);
    if (!mounted) return;
    if (error == null) {
      _controller.clear();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }
}

class _PublicationHeader extends StatelessWidget {
  const _PublicationHeader({required this.conversation, required this.onTap});

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox.square(
                  dimension: 48,
                  child: PublicationImage(
                    url: conversation.publicationImageUrl,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.publicationTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      conversation.publicationMode == 'intercambio'
                          ? 'Intercambio'
                          : 'Donación',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isOwn});

  final ChatMessage message;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 9, 10, 6),
        decoration: BoxDecoration(
          color: isOwn
              ? AppColors.primary.withValues(alpha: 0.16)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Align(alignment: Alignment.centerLeft, child: Text(message.body)),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.isPending) ...[
                  const Icon(Icons.schedule, size: 13),
                  const SizedBox(width: 3),
                  const Text('Pendiente · '),
                ],
                Text(_messageTime(message.sentAt)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                maxLength: 1000,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Escribe un mensaje',
                  counterText: '',
                ),
              ),
            ),
            IconButton(
              tooltip: 'Enviar',
              onPressed: enabled ? onSend : null,
              icon: const Icon(Icons.send),
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

String _messageTime(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)} '
      '${two(local.hour)}:${two(local.minute)}';
}
