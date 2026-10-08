import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/domain/publication.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/button_spinner.dart';
import '../../../shared/widgets/publication_image.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../exchange/presentation/exchange_activity_page.dart';
import '../../exchange/presentation/exchange_controller.dart';
import '../../exchange/presentation/propose_exchange_sheet.dart';
import '../../delivery/presentation/delivery_controller.dart';
import '../../delivery/presentation/register_delivery_page.dart';
import '../../messaging/data/messaging_repository.dart';
import '../../messaging/domain/conversation.dart';
import '../../messaging/presentation/conversation_page.dart';
import '../../moderation/presentation/report_publication_sheet.dart';
import '../../profile/presentation/public_profile_page.dart';
import '../../publishing/presentation/publish_controller.dart';
import '../domain/public_profile.dart';
import 'explore_controller.dart';
import 'widgets/publication_mode_badge.dart';

class PublicationDetailPage extends ConsumerWidget {
  const PublicationDetailPage({super.key, required this.initial});

  final Publication initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remote = ref.watch(publicationDetailProvider(initial.id));
    final publication = remote.value ?? initial;
    final profile = ref.watch(publicProfileProvider(publication.authorId));
    final currentUserId = ref.watch(authStateProvider).value?.uid;
    final now = ref.watch(exchangeClockProvider).value ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del bien')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _PhotoGallery(images: publication.images),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        publication.title,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    PublicationModeBadge(mode: publication.mode),
                  ],
                ),
                const SizedBox(height: 12),
                _FactRow(
                  icon: Icons.location_on_outlined,
                  label: publication.district,
                ),
                _FactRow(
                  icon: Icons.category_outlined,
                  label: publication.category,
                ),
                _FactRow(
                  icon: Icons.inventory_2_outlined,
                  label: publication.condition,
                ),
                if (publication.deliveryType != null)
                  _FactRow(
                    icon: publication.deliveryType == DeliveryType.owner
                        ? Icons.person_outline
                        : Icons.volunteer_activism_outlined,
                    label: publication.deliveryType!.label,
                  ),
                const SizedBox(height: 4),
                Text(
                  timeAgo(publication.publishedAt),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: context.appColors.textSecondary),
                ),
                const SizedBox(height: 8),
                _PublicationTimeline(publication: publication, now: now),
                const Divider(),
                Text(
                  'Descripción',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(publication.description),
                if (publication.details.isNotEmpty) ...[
                  const Divider(),
                  Text(
                    'Detalles',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final detail in publication.details)
                        Chip(label: Text('${detail.name}: ${detail.value}')),
                    ],
                  ),
                ],
                const Divider(),
                Text(
                  'Publicado por',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                profile.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stackTrace) => Text(
                    'No se pudo cargar el perfil público.',
                    style: TextStyle(color: context.appColors.textSecondary),
                  ),
                  data: (owner) => _AuthorRow(
                    owner: owner,
                    // La conversación se inicia desde el detalle y no desde el
                    // perfil público (HU20, criterio 20), así que la fila solo
                    // lleva al perfil.
                    onTap: owner == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PublicProfilePage(
                                userId: publication.authorId,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                _PublicationActions(
                  publication: publication,
                  currentUserId: currentUserId,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicationTimeline extends StatelessWidget {
  const _PublicationTimeline({required this.publication, required this.now});

  final Publication publication;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final effectiveStatus = publication.effectiveStatus(now);
    final entries = <(PublicationStatus, DateTime)>[
      (
        PublicationStatus.published,
        publication.statusDates[PublicationStatus.published] ??
            publication.publishedAt,
      ),
      for (final status in const [
        PublicationStatus.committed,
        PublicationStatus.pickedUp,
        PublicationStatus.delivered,
        PublicationStatus.confirmed,
      ])
        if (publication.statusDates[status] case final date?)
          if (status != PublicationStatus.committed ||
              publication.status != PublicationStatus.published)
            (status, date),
    ];
    // Los hitos por vencimiento no están en statusDates (D02): se calculan a
    // partir de la entrega.
    final deliveredAt = publication.statusDates[PublicationStatus.delivered];
    if (deliveredAt != null &&
        (effectiveStatus == PublicationStatus.pendingConfirmation ||
            effectiveStatus == PublicationStatus.closedWithoutConfirmation)) {
      entries.add((
        PublicationStatus.pendingConfirmation,
        deliveredAt.add(Publication.pendingConfirmationAfter),
      ));
      if (effectiveStatus == PublicationStatus.closedWithoutConfirmation) {
        entries.add((
          PublicationStatus.closedWithoutConfirmation,
          deliveredAt.add(Publication.closeWithoutConfirmationAfter),
        ));
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recorrido',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < entries.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == entries.length - 1 ? 0 : 9,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: context.appColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(entries[index].$1.label)),
                  Text(
                    formatDateTime(entries[index].$2),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: context.appColors.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Fila "Publicado por" del detalle. Abre el perfil público de quien publicó
/// (HU20, criterio 12).
///
/// Se sustituyó el `ListTile` por una fila propia para poder dejar la fila sin
/// destino cuando `perfiles/{uid}` no existe: un `ListTile` con `onTap` nulo
/// sigue leyéndose como algo pulsable.
class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.owner, this.onTap});

  final PublicProfile? owner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;
    final shortName = owner?.shortName ?? '';
    final district = owner?.district ?? '';

    return Semantics(
      button: onTap != null,
      label:
          'Ver el perfil de ${shortName.isEmpty ? 'quien publicó' : shortName}',
      excludeSemantics: true,
      container: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: palette.primary,
                foregroundColor: palette.onPrimary,
                child: Text(
                  shortName.isEmpty ? '?' : shortName[0].toUpperCase(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shortName.isEmpty ? 'Usuario de ReHomeIt' : shortName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (district.isNotEmpty)
                      Text(
                        district,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: palette.textSecondary),
                      ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: palette.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoGallery extends StatelessWidget {
  const _PhotoGallery({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    final urls = images.isEmpty ? const <String?>[null] : images;
    return SizedBox(
      height: 320,
      child: PageView.builder(
        itemCount: urls.length,
        itemBuilder: (context, index) => PublicationImage(url: urls[index]),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 19, color: context.appColors.textSecondary),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _PublicationActions extends ConsumerWidget {
  const _PublicationActions({
    required this.publication,
    required this.currentUserId,
  });

  final Publication publication;
  final String? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = currentUserId;
    if (userId == null) return const SizedBox.shrink();
    final isOwner = userId == publication.authorId;
    final isVolunteer = userId == publication.volunteerId;
    final busy = ref.watch(deliveryControllerProvider).isLoading;

    if (publication.mode == PublicationMode.donation) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (publication.status == PublicationStatus.published &&
              publication.deliveryType == DeliveryType.volunteer &&
              !isOwner)
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => _assumePickup(context, ref, userId),
              icon: const Icon(Icons.volunteer_activism_outlined),
              label: const Text('Asumir recojo'),
            ),
          if (publication.status == PublicationStatus.published &&
              publication.deliveryType == DeliveryType.owner &&
              isOwner)
            FilledButton.icon(
              onPressed: () => _openDeliveryForm(context),
              icon: const Icon(Icons.redeem_outlined),
              label: const Text('Registrar entrega al destinatario'),
            ),
          if (publication.status == PublicationStatus.committed && isOwner)
            FilledButton.icon(
              onPressed: busy ? null : () => _confirmHandoff(context, ref),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Confirmar entrega al voluntario'),
            ),
          if (publication.status == PublicationStatus.pickedUp && isVolunteer)
            FilledButton.icon(
              onPressed: () => _openDeliveryForm(context),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Registrar entrega al destinatario'),
            ),
          if (publication.status == PublicationStatus.committed &&
              (isOwner || isVolunteer)) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : () => _release(context, ref, userId),
              icon: const Icon(Icons.undo),
              label: Text(
                isOwner ? 'Cancelar compromiso' : 'Desistir del recojo',
              ),
            ),
          ],
          if (publication.status == PublicationStatus.pickedUp && isOwner)
            const _ActionNotice(
              icon: Icons.local_shipping_outlined,
              text: 'Entrega en curso. El voluntario trasladará el bien al destinatario.',
            ),
          if (publication.status == PublicationStatus.published && isOwner) ...[
            const SizedBox(height: 10),
            _withdrawButton(context, ref),
          ],
          if (!isOwner) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _openConversation(context, ref, userId),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Enviar mensaje'),
            ),
          ] else if (publication.volunteerId != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _openConversation(context, ref, userId),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Coordinar con el voluntario'),
            ),
          ],
          if (publication.status == PublicationStatus.delivered)
            const _ActionNotice(
              icon: Icons.check_circle_outline,
              text: 'La entrega al destinatario fue registrada.',
            ),
          if (publication.status == PublicationStatus.confirmed)
            const _ActionNotice(
              icon: Icons.verified_outlined,
              text: 'Donación confirmada.',
            ),
          if (!isOwner) ...[
            const SizedBox(height: 10),
            _ReportAction(publication: publication),
          ],
        ],
      );
    }

    if (isOwner) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (publication.status == PublicationStatus.published) ...[
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExchangeActivityPage()),
              ),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Ver propuestas de intercambio'),
            ),
            const SizedBox(height: 10),
            _withdrawButton(context, ref),
          ] else
            const _ActionNotice(
              icon: Icons.person_outline,
              text: 'Consulta el avance en Mis intercambios.',
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (publication.isAvailable)
          FilledButton.icon(
            onPressed: () async {
              final proposed = await showProposeExchangeSheet(
                context,
                requestedPublication: publication,
              );
              if (proposed == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Propuesta enviada')),
                );
              }
            },
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Proponer intercambio'),
          )
        else
          const _ActionNotice(
            icon: Icons.lock_clock_outlined,
            text: 'Esta publicación ya no está disponible.',
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _openConversation(context, ref, userId),
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Enviar mensaje'),
        ),
        const SizedBox(height: 10),
        _ReportAction(publication: publication),
      ],
    );
  }

  Widget _withdrawButton(BuildContext context, WidgetRef ref) {
    final withdrawing = ref.watch(publishControllerProvider).isLoading;
    return OutlinedButton.icon(
      onPressed: withdrawing ? null : () => _withdraw(context, ref),
      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
      icon: withdrawing
          ? const ButtonSpinner()
          : const Icon(Icons.remove_circle_outline),
      label: const Text('Retirar publicación'),
    );
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirmDialog(
      context,
      icon: Icons.remove_circle_outline,
      destructive: true,
      title: '¿Retirar la publicación?',
      subtitle:
          'El bien dejará de aparecer en el listado y no se puede deshacer.',
      confirmLabel: 'Retirar',
    );
    if (!confirmed || !context.mounted) return;

    final error = await ref
        .read(publishControllerProvider.notifier)
        .withdraw(publication.id);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Publicación retirada')),
    );
  }

  Future<void> _assumePickup(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      icon: Icons.volunteer_activism_outlined,
      title: 'Asumir recojo',
      subtitle:
          'Te comprometes a recoger este bien y coordinar con el donante.',
      confirmLabel: 'Asumir',
    );
    if (!confirmed || !context.mounted) return;
    final error = await ref
        .read(deliveryControllerProvider.notifier)
        .assume(publication, userId);
    if (context.mounted) {
      _showOutcome(
        context,
        error,
        'Recojo asumido. Ya puedes coordinar por mensajes.',
      );
    }
  }

  Future<void> _release(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final isOwner = userId == publication.authorId;
    final confirmed = await showAppConfirmDialog(
      context,
      icon: Icons.undo,
      title: isOwner ? 'Cancelar compromiso' : 'Desistir del recojo',
      subtitle: 'El bien volverá a estar disponible para otros usuarios.',
      // "Cancelar" junto a "Cancelar compromiso" sería ambiguo.
      cancelLabel: 'Volver',
      confirmLabel: isOwner ? 'Cancelar compromiso' : 'Desistir',
    );
    if (!confirmed || !context.mounted) return;
    final error = await ref
        .read(deliveryControllerProvider.notifier)
        .release(publication, userId);
    if (context.mounted) {
      _showOutcome(context, error, 'El bien volvió a estar disponible.');
    }
  }

  Future<void> _confirmHandoff(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirmDialog(
      context,
      icon: Icons.inventory_2_outlined,
      title: 'Confirmar entrega al voluntario',
      subtitle:
          'Confirma únicamente si el voluntario ya recibió el bien. '
          'Esta operación no puede revertirse.',
      confirmLabel: 'Confirmar entrega',
    );
    if (!confirmed || !context.mounted) return;
    final error = await ref
        .read(deliveryControllerProvider.notifier)
        .confirmHandoff(publication, publication.authorId);
    if (context.mounted) {
      _showOutcome(
        context,
        error,
        'Entrega confirmada. El traslado está en curso.',
      );
    }
  }

  void _openDeliveryForm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegisterDeliveryPage(publication: publication),
      ),
    );
  }

  Future<void> _openConversation(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    try {
      Conversation? conversation;
      if (userId == publication.authorId && publication.volunteerId != null) {
        final id = MessagingRepository.conversationId(
          publicationId: publication.id,
          firstUserId: publication.authorId,
          secondUserId: publication.volunteerId!,
        );
        conversation = await ref
            .read(messagingRepositoryProvider)
            .getConversation(id);
      } else {
        conversation = await ref
            .read(messagingRepositoryProvider)
            .startConversation(publication: publication, userId: userId);
      }
      if (!context.mounted) return;
      if (conversation == null) {
        showAppSnackBar(
          context,
          'La conversación aún no está disponible.',
          kind: AppSnackBarKind.error,
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConversationPage(conversation: conversation!),
        ),
      );
    } on MessagingFailure catch (error) {
      if (context.mounted) {
        showAppSnackBar(context, error.message, kind: AppSnackBarKind.error);
      }
    }
  }

  void _showOutcome(BuildContext context, String? error, String success) {
    showAppSnackBar(
      context,
      error ?? success,
      kind: error != null ? AppSnackBarKind.error : AppSnackBarKind.success,
    );
  }
}

class _ReportAction extends StatelessWidget {
  const _ReportAction({required this.publication});

  final Publication publication;

  @override
  Widget build(BuildContext context) {
    // Botón de texto y no el icono de la tarjeta del feed: en el detalle la
    // acción tiene que decir qué hace, porque reportar es la única que
    // responde a algo que nadie más ve.
    return TextButton.icon(
      onPressed: () => reportPublication(context, publication: publication),
      icon: const Icon(Icons.flag_outlined, size: 18),
      label: const Text('Reportar publicación'),
    );
  }
}

class _ActionNotice extends StatelessWidget {
  const _ActionNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.appColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
