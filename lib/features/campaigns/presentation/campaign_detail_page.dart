import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/campaign.dart';
import '../domain/contribution.dart';
import 'campaign_controller.dart';
import 'campaign_form_page.dart';
import 'contribution_controller.dart';
import 'widgets/campaign_progress.dart';
import 'widgets/contribution_review.dart';
import 'widgets/contribution_sheet.dart';
import 'widgets/pending_contribution_card.dart';

class CampaignDetailPage extends ConsumerWidget {
  const CampaignDetailPage({super.key, required this.initial});

  final Campaign initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaign = ref.watch(campaignProvider(initial.id)).value ?? initial;
    final userId = ref.watch(authStateProvider).value?.uid ?? '';
    final access = userId.isEmpty
        ? null
        : ref.watch(campaignAccessProvider(userId)).value;
    final now =
        ref.watch(campaignClockProvider).value ?? DateTime.now().toUtc();
    final closed = campaign.isClosedAt(now);
    final canEdit =
        access?.isOrganization == true &&
        campaign.canEdit(userId: userId, now: now);
    final isAdmin = access?.isAdmin == true;
    final canClose =
        access != null &&
        campaign.canCloseEarly(
          userId: userId,
          isOrganization: access.isOrganization,
          isAdmin: isAdmin,
          now: now,
        );
    final canContribute =
        !closed && userId.isNotEmpty && userId != campaign.organizationId;
    final isOwner =
        access?.isOrganization == true && campaign.organizationId == userId;
    final pendingContributions = isOwner
        ? (ref
                      .watch(pendingContributionsByOrganizationProvider(userId))
                      .value ??
                  const <Contribution>[])
              .where((item) => item.campaignId == campaign.id)
              .toList(growable: false)
        : const <Contribution>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de campaña'),
        actions: [
          if (canEdit)
            IconButton(
              key: const Key('edit-campaign-button'),
              tooltip: 'Editar campaña',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CampaignFormPage(initial: campaign),
                ),
              ),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (campaign.imageUrl case final url?) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: context.appColors.border,
                    child: const Center(
                      child: Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  campaign.title,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              _DetailStatus(closed: closed),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            campaign.organizationName,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '${campaign.district} · ${closed ? 'Cerrada' : _remaining(campaign.daysRemaining(now))}',
            style: TextStyle(color: context.appColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Cierre: ${formatDateTime(campaign.closeAt)}',
            style: TextStyle(color: context.appColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Text(campaign.description),
          if (canContribute) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('contribute-campaign-button'),
              onPressed: () => _contribute(context, ref, campaign, userId),
              icon: const Icon(Icons.volunteer_activism_outlined),
              label: const Text('Registrar un aporte'),
            ),
          ],
          const SizedBox(height: 24),
          Text('Avance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          CampaignProgress(campaign: campaign),
          const SizedBox(height: 24),
          Text('Necesidades', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final need in campaign.needs)
            _NeedTile(campaign: campaign, need: need),
          if (pendingContributions.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Aportes pendientes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Confirma los bienes que ya recibiste o rechaza los que no llegaron.',
              style: TextStyle(color: context.appColors.textSecondary),
            ),
            const SizedBox(height: 8),
            for (final contribution in pendingContributions)
              PendingContributionCard(
                contribution: contribution,
                onConfirm: () =>
                    confirmContribution(context, ref, contribution, userId),
                onReject: () =>
                    rejectContribution(context, ref, contribution, userId),
              ),
          ],
          const SizedBox(height: 16),
          Text(
            'Punto de acopio',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PointRow(
                    icon: Icons.place_outlined,
                    text: campaign.collectionPoint.name,
                  ),
                  _PointRow(
                    icon: Icons.location_on_outlined,
                    text: campaign.collectionPoint.address,
                  ),
                  _PointRow(
                    icon: Icons.schedule_outlined,
                    text: campaign.collectionPoint.openingHours,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'Al cerrarse la campaña se publicará un resumen con lo recibido y su destino.',
            ),
          ),
          if (campaign.hasPendingWrites) ...[
            const SizedBox(height: 14),
            const Text(
              'Los últimos cambios están pendientes de sincronización.',
              style: TextStyle(color: AppColors.warning),
            ),
          ],
          if (canClose) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              key: const Key('close-campaign-button'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () => _close(
                context,
                ref,
                campaign,
                closedBy: userId,
                reason: isAdmin
                    ? CampaignClosureReasons.byAdministration
                    : CampaignClosureReasons.byOrganization,
              ),
              icon: const Icon(Icons.lock_outline),
              label: const Text('Cerrar campaña anticipadamente'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _close(
    BuildContext context,
    WidgetRef ref,
    Campaign campaign, {
    required String closedBy,
    required String reason,
  }) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '¿Cerrar esta campaña?',
      subtitle: 'El cierre es definitivo y la campaña no podrá reabrirse.',
      cancelLabel: 'Cancelar',
      confirmLabel: 'Cerrar campaña',
    );
    if (!confirmed || !context.mounted) return;
    final error = await ref
        .read(campaignControllerProvider.notifier)
        .closeEarly(
          campaignId: campaign.id,
          closedBy: closedBy,
          reason: reason,
        );
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      error ?? 'Campaña cerrada.',
      kind: error == null ? AppSnackBarKind.success : AppSnackBarKind.error,
    );
  }

  Future<void> _contribute(
    BuildContext context,
    WidgetRef ref,
    Campaign campaign,
    String userId,
  ) async {
    final request = await showContributionSheet(context, campaign: campaign);
    if (request == null || !context.mounted) return;
    final error = await ref
        .read(contributionControllerProvider.notifier)
        .register(
          campaign: campaign,
          need: request.need,
          quantity: request.quantity,
          contributorId: userId,
        );
    if (!context.mounted) return;
    if (error != null) {
      showAppSnackBar(context, error, kind: AppSnackBarKind.error);
      return;
    }
    await _showCollectionPoint(context, campaign);
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      'Tu aporte quedó pendiente. La organización lo confirmará al recibirlo.',
      kind: AppSnackBarKind.success,
    );
  }

  Future<void> _showCollectionPoint(BuildContext context, Campaign campaign) {
    return showDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: 'Aporte registrado',
        subtitle:
            'Queda en estado Pendiente hasta que la organización lo confirme.',
        header: const AppDialogIcon(icon: Icons.volunteer_activism_outlined),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acércalo al punto de acopio:',
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: context.appColors.textSecondary),
            ),
            const SizedBox(height: 6),
            _PointRow(
              icon: Icons.place_outlined,
              text: campaign.collectionPoint.name,
            ),
            _PointRow(
              icon: Icons.location_on_outlined,
              text: campaign.collectionPoint.address,
            ),
            _PointRow(
              icon: Icons.schedule_outlined,
              text: campaign.collectionPoint.openingHours,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

class _NeedTile extends StatelessWidget {
  const _NeedTile({required this.campaign, required this.need});

  final Campaign campaign;
  final CampaignNeed need;

  @override
  Widget build(BuildContext context) {
    final contributed = campaign.contributedFor(need.id);
    final covered = contributed >= need.requiredQuantity;
    return Card(
      child: ListTile(
        title: Text(need.name),
        subtitle: Text(
          '$contributed aportado de ${need.requiredQuantity} requerido',
        ),
        trailing: covered
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Cubierta',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: context.appColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _DetailStatus extends StatelessWidget {
  const _DetailStatus({required this.closed});

  final bool closed;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(closed ? 'Cerrada' : 'Activa'),
    backgroundColor: (closed ? context.appColors.border : AppColors.success)
        .withValues(alpha: closed ? 1 : 0.14),
    side: BorderSide.none,
  );
}

String _remaining(int days) => days == 1 ? 'queda 1 día' : 'quedan $days días';
