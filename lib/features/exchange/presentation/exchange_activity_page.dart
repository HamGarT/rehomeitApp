import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/domain/publication.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/publication_image.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../explore/data/explore_repository.dart';
import '../../messaging/data/messaging_repository.dart';
import '../../messaging/presentation/conversation_page.dart';
import '../domain/exchange_proposal.dart';
import 'exchange_controller.dart';

class ExchangeActivityPage extends ConsumerWidget {
  const ExchangeActivityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis intercambios')),
      body: user == null
          ? const Center(
              child: Text('Inicia sesión para ver tus intercambios.'),
            )
          : ref
                .watch(userExchangeProposalsProvider(user.uid))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => _ExchangeError(
                    onRetry: () =>
                        ref.invalidate(userExchangeProposalsProvider(user.uid)),
                  ),
                  data: (proposals) => proposals.isEmpty
                      ? const _NoExchanges()
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: proposals.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) => _ProposalCard(
                            proposal: proposals[index],
                            userId: user.uid,
                          ),
                        ),
                ),
    );
  }
}

class _ProposalCard extends ConsumerWidget {
  const _ProposalCard({required this.proposal, required this.userId});

  final ExchangeProposal proposal;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = proposal.requestedOwnerId == userId;
    final now = ref.watch(exchangeClockProvider).value ?? DateTime.now();
    final effectiveStatus = proposal.effectivePublicationStatus(now);
    final busy = ref.watch(exchangeControllerProvider).isLoading;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    incoming ? 'Propuesta recibida' : 'Propuesta enviada',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                _ProposalStatusBadge(
                  label: proposal.status == ExchangeProposalStatus.accepted
                      ? effectiveStatus.label
                      : proposal.status.label,
                  positive:
                      proposal.status == ExchangeProposalStatus.accepted &&
                      effectiveStatus !=
                          PublicationStatus.pendingConfirmation &&
                      effectiveStatus !=
                          PublicationStatus.closedWithoutConfirmation,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ProposalItem(
              caption: 'Solicitada',
              title: proposal.requestedPublicationTitle,
              imageUrl: proposal.requestedImageUrl,
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 7),
              child: Center(
                child: Icon(Icons.swap_vert, color: context.appColors.primary),
              ),
            ),
            _ProposalItem(
              caption: 'Ofrecida',
              title: proposal.offeredPublicationTitle,
              imageUrl: proposal.offeredImageUrl,
            ),
            const SizedBox(height: 12),
            Text(
              'Propuesta: ${formatDateTime(proposal.proposedAt)}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: context.appColors.textSecondary),
            ),
            if (proposal.respondedAt != null)
              Text(
                'Respuesta: ${formatDateTime(proposal.respondedAt!)}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: context.appColors.textSecondary),
              ),
            if (proposal.requestedOwnerConfirmedAt != null)
              Text(
                'Confirmación del propietario solicitado: ${formatDateTime(proposal.requestedOwnerConfirmedAt!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (proposal.offeredOwnerConfirmedAt != null)
              Text(
                'Confirmación del proponente: ${formatDateTime(proposal.offeredOwnerConfirmedAt!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (incoming &&
                proposal.status == ExchangeProposalStatus.pending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => _respond(context, ref, accept: false),
                      child: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: busy
                          ? null
                          : () => _respond(context, ref, accept: true),
                      child: const Text('Aceptar'),
                    ),
                  ),
                ],
              ),
            ],
            if (proposal.status == ExchangeProposalStatus.accepted &&
                !proposal.hasConfirmed(userId)) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: busy ? null : () => _confirm(context, ref),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirmar que recibí el bien'),
              ),
            ],
            if (proposal.status == ExchangeProposalStatus.accepted &&
                proposal.hasConfirmed(userId) &&
                !proposal.bothConfirmed) ...[
              const SizedBox(height: 12),
              Text(
                'Tu recepción está confirmada. Esperando la confirmación de la otra parte.',
                style: TextStyle(color: context.appColors.textSecondary),
              ),
            ],
            // Lugar, fecha y condiciones se acuerdan por mensajería (HU07-7).
            // Solo tiene sentido con la propuesta aceptada: antes no hay nada
            // que coordinar y el detalle ya permite preguntar.
            if (proposal.status == ExchangeProposalStatus.accepted) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _coordinate(context, ref),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Coordinar por mensaje'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// La conversación se ancla a la publicación solicitada, igual que la que
  /// nace desde su detalle, para que ambas partes lleguen al mismo hilo.
  Future<void> _coordinate(BuildContext context, WidgetRef ref) async {
    final incoming = proposal.requestedOwnerId == userId;
    final counterpartId = incoming
        ? proposal.offeredOwnerId
        : proposal.requestedOwnerId;
    try {
      final publication = await ref
          .read(exploreRepositoryProvider)
          .watchPublication(proposal.requestedPublicationId)
          .first;
      if (!context.mounted) return;
      if (publication == null) {
        showAppSnackBar(
          context,
          'La publicación ya no está disponible.',
          kind: AppSnackBarKind.error,
        );
        return;
      }
      final conversation = await ref
          .read(messagingRepositoryProvider)
          .startConversation(
            publication: publication,
            userId: userId,
            counterpartId: counterpartId,
          );
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConversationPage(conversation: conversation),
        ),
      );
    } on MessagingFailure catch (error) {
      if (context.mounted) {
        showAppSnackBar(context, error.message, kind: AppSnackBarKind.error);
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          'No se pudo abrir la conversación.',
          kind: AppSnackBarKind.error,
        );
      }
    }
  }

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref, {
    required bool accept,
  }) async {
    final confirmed = await showAppConfirmDialog(
      context,
      icon: accept ? Icons.swap_horiz : Icons.close,
      destructive: !accept,
      title: accept ? 'Aceptar intercambio' : 'Rechazar propuesta',
      subtitle: accept
          ? 'Ambas publicaciones pasarán a Comprometida.'
          : 'La publicación seguirá disponible para otras propuestas.',
      confirmLabel: accept ? 'Aceptar' : 'Rechazar',
    );
    if (!confirmed || !context.mounted) return;

    final error = await ref
        .read(exchangeControllerProvider.notifier)
        .respond(proposalId: proposal.id, ownerId: userId, accept: accept);
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      error ?? (accept ? 'Propuesta aceptada' : 'Propuesta rechazada'),
      kind: error != null ? AppSnackBarKind.error : AppSnackBarKind.success,
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirmDialog(
      context,
      icon: Icons.check_circle_outline,
      title: 'Confirmar recepción',
      subtitle: 'Confirma solo cuando ya hayas recibido el bien acordado.',
      cancelLabel: 'Volver',
      confirmLabel: 'Confirmar',
    );
    if (!confirmed || !context.mounted) return;

    final error = await ref
        .read(exchangeControllerProvider.notifier)
        .confirmReceipt(proposalId: proposal.id, userId: userId);
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      error ?? 'Recepción confirmada',
      kind: error != null ? AppSnackBarKind.error : AppSnackBarKind.success,
    );
  }
}

class _ProposalItem extends StatelessWidget {
  const _ProposalItem({
    required this.caption,
    required this.title,
    required this.imageUrl,
  });

  final String caption;
  final String title;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox.square(
            dimension: 54,
            child: PublicationImage(url: imageUrl),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                caption,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: context.appColors.textSecondary),
              ),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProposalStatusBadge extends StatelessWidget {
  const _ProposalStatusBadge({required this.label, required this.positive});

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final accent = positive ? context.appColors.primary : AppColors.accent;
    return AppBadge(
      label: label,
      background: accent.withValues(alpha: 0.18),
      foreground: positive ? context.appColors.primary : AppColors.warning,
    );
  }
}

class _NoExchanges extends StatelessWidget {
  const _NoExchanges();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_horiz,
              size: 52,
              color: context.appColors.textSecondary,
            ),
            const SizedBox(height: 12),
            const Text('Todavía no tienes propuestas de intercambio.'),
          ],
        ),
      ),
    );
  }
}

class _ExchangeError extends StatelessWidget {
  const _ExchangeError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('No pudimos cargar tus intercambios.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
