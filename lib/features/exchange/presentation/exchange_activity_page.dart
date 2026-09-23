import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/domain/publication.dart';
import '../../../shared/widgets/publication_image.dart';
import '../../auth/presentation/auth_controller.dart';
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
                _StatusBadge(
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 7),
              child: Center(
                child: Icon(Icons.swap_vert, color: AppColors.primary),
              ),
            ),
            _ProposalItem(
              caption: 'Ofrecida',
              title: proposal.offeredPublicationTitle,
              imageUrl: proposal.offeredImageUrl,
            ),
            const SizedBox(height: 12),
            Text(
              'Propuesta: ${_formatDate(proposal.proposedAt)}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            if (proposal.respondedAt != null)
              Text(
                'Respuesta: ${_formatDate(proposal.respondedAt!)}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            if (proposal.requestedOwnerConfirmedAt != null)
              Text(
                'Confirmación del propietario solicitado: ${_formatDate(proposal.requestedOwnerConfirmedAt!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (proposal.offeredOwnerConfirmedAt != null)
              Text(
                'Confirmación del proponente: ${_formatDate(proposal.offeredOwnerConfirmedAt!)}',
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
              const Text(
                'Tu recepción está confirmada. Esperando la confirmación de la otra parte.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref, {
    required bool accept,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(accept ? 'Aceptar intercambio' : 'Rechazar propuesta'),
        content: Text(
          accept
              ? 'Ambas publicaciones pasarán a Comprometida. ¿Deseas continuar?'
              : 'La publicación seguirá disponible para otras propuestas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(accept ? 'Aceptar' : 'Rechazar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final error = await ref
        .read(exchangeControllerProvider.notifier)
        .respond(proposalId: proposal.id, ownerId: userId, accept: accept);
    if (!context.mounted) return;
    _showResult(
      context,
      error ?? (accept ? 'Propuesta aceptada' : 'Propuesta rechazada'),
      isError: error != null,
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar recepción'),
        content: const Text(
          'Confirma solo cuando ya hayas recibido el bien acordado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final error = await ref
        .read(exchangeControllerProvider.notifier)
        .confirmReceipt(proposalId: proposal.id, userId: userId);
    if (!context.mounted) return;
    _showResult(
      context,
      error ?? 'Recepción confirmada',
      isError: error != null,
    );
  }

  void _showResult(
    BuildContext context,
    String message, {
    required bool isError,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.error : AppColors.success,
        ),
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
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.positive});

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: (positive ? AppColors.primary : AppColors.accent).withValues(
          alpha: 0.18,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: positive ? AppColors.primary : AppColors.warning,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NoExchanges extends StatelessWidget {
  const _NoExchanges();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz, size: 52, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text('Todavía no tienes propuestas de intercambio.'),
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

String _formatDate(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
