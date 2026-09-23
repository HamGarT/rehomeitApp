import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/domain/publication.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/publication_image.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../exchange/presentation/exchange_activity_page.dart';
import '../../exchange/presentation/exchange_controller.dart';
import '../../exchange/presentation/propose_exchange_sheet.dart';
import '../../publishing/presentation/publish_controller.dart';
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
                  error: (error, stackTrace) => const Text(
                    'No se pudo cargar el perfil público.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  data: (owner) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.surface,
                      child: Text(
                        owner?.shortName.isNotEmpty == true
                            ? owner!.shortName[0].toUpperCase()
                            : '?',
                      ),
                    ),
                    title: Text(owner?.shortName ?? 'Usuario de ReHomeIt'),
                    subtitle: owner?.district.isNotEmpty == true
                        ? Text(owner!.district)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                _PublicationActions(
                  publication: publication,
                  isOwner: currentUserId == publication.authorId,
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
        PublicationStatus.delivered,
        PublicationStatus.confirmed,
      ])
        if (publication.statusDates[status] case final date?) (status, date),
    ];
    final deliveredAt = publication.statusDates[PublicationStatus.delivered];
    if (deliveredAt != null &&
        effectiveStatus == PublicationStatus.pendingConfirmation) {
      entries.add((
        PublicationStatus.pendingConfirmation,
        deliveredAt.add(const Duration(hours: 48)),
      ));
    }
    if (deliveredAt != null &&
        effectiveStatus == PublicationStatus.closedWithoutConfirmation) {
      entries
        ..add((
          PublicationStatus.pendingConfirmation,
          deliveredAt.add(const Duration(hours: 48)),
        ))
        ..add((
          PublicationStatus.closedWithoutConfirmation,
          deliveredAt.add(const Duration(hours: 72)),
        ));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
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
                  const Icon(
                    Icons.check_circle,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(entries[index].$1.label)),
                  Text(
                    _formatDate(entries[index].$2),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
        ],
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
          Icon(icon, size: 19, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _PublicationActions extends ConsumerWidget {
  const _PublicationActions({required this.publication, required this.isOwner});

  final Publication publication;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!publication.isAvailable) {
      return const _ActionNotice(
        icon: Icons.lock_clock_outlined,
        text: 'Esta publicación ya no está disponible.',
      );
    }
    if (isOwner) {
      final withdrawing = ref.watch(publishControllerProvider).isLoading;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (publication.mode == PublicationMode.exchange)
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExchangeActivityPage()),
              ),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Ver propuestas de intercambio'),
            )
          else
            const _ActionNotice(
              icon: Icons.person_outline,
              text: 'Esta es tu publicación.',
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: withdrawing ? null : () => _withdraw(context, ref),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
            icon: withdrawing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.remove_circle_outline),
            label: const Text('Retirar publicación'),
          ),
        ],
      );
    }
    if (publication.mode == PublicationMode.donation) {
      final volunteer = publication.deliveryType == DeliveryType.volunteer;
      return _ActionNotice(
        icon: volunteer
            ? Icons.volunteer_activism_outlined
            : Icons.redeem_outlined,
        text: volunteer
            ? 'Esta donación está disponible para recojo por voluntariado.'
            : 'El donante realizará personalmente la entrega.',
      );
    }
    return FilledButton.icon(
      onPressed: () async {
        final proposed = await showProposeExchangeSheet(
          context,
          requestedPublication: publication,
        );
        if (proposed == true && context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Propuesta enviada')));
        }
      },
      icon: const Icon(Icons.swap_horiz),
      label: const Text('Proponer intercambio'),
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
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
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
