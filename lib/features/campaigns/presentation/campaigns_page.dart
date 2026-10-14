import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_routes.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/campaign.dart';
import 'campaign_controller.dart';
import 'campaign_detail_page.dart';
import 'campaign_form_page.dart';
import 'widgets/campaign_progress.dart';

class CampaignsPage extends ConsumerWidget {
  const CampaignsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authStateProvider).value?.uid ?? '';
    final access = userId.isEmpty
        ? null
        : ref.watch(campaignAccessProvider(userId)).value;
    final campaigns = ref.watch(campaignsProvider);
    final now =
        ref.watch(campaignClockProvider).value ?? DateTime.now().toUtc();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          if (access?.isOrganization == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: FilledButton.icon(
                key: const Key('create-campaign-button'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CampaignFormPage()),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Crear campaña'),
              ),
            ),
          const TabBar(
            tabs: [
              Tab(text: 'Activas'),
              Tab(text: 'Cerradas'),
            ],
          ),
          Expanded(
            child: campaigns.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _CampaignError(
                onRetry: () => ref.invalidate(campaignsProvider),
              ),
              data: (items) {
                final active =
                    items.where((item) => !item.isClosedAt(now)).toList()
                      ..sort((a, b) => a.closeAt.compareTo(b.closeAt));
                final closed =
                    items.where((item) => item.isClosedAt(now)).toList()
                      ..sort((a, b) => b.closeAt.compareTo(a.closeAt));
                return TabBarView(
                  children: [
                    _CampaignList(
                      items: active,
                      active: true,
                      now: now,
                      onRefresh: () => _refresh(ref),
                    ),
                    _CampaignList(
                      items: closed,
                      active: false,
                      now: now,
                      onRefresh: () => _refresh(ref),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(campaignsProvider);
    await ref.read(campaignsProvider.future);
  }
}

class _CampaignList extends StatelessWidget {
  const _CampaignList({
    required this.items,
    required this.active,
    required this.now,
    required this.onRefresh,
  });

  final List<Campaign> items;
  final bool active;
  final DateTime now;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            active
                ? 'No hay campañas activas por ahora.'
                : 'Todavía no hay campañas cerradas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.appColors.textSecondary),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            CampaignCard(campaign: items[index], now: now),
      ),
    );
  }
}

class CampaignCard extends StatelessWidget {
  const CampaignCard({super.key, required this.campaign, this.now});

  final Campaign campaign;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final effectiveNow = now ?? DateTime.now().toUtc();
    final closed = campaign.isClosedAt(effectiveNow);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => pushUnique(
          context,
          name: AppRoutes.campaign(campaign.id),
          builder: (_) => CampaignDetailPage(initial: campaign),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (campaign.imageUrl case final url?) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _ImageFallback(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      campaign.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _StatusBadge(closed: closed),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${campaign.organizationName} · ${campaign.district}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: context.appColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                closed
                    ? 'Campaña cerrada'
                    : _remainingLabel(campaign.daysRemaining(effectiveNow)),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: closed
                      ? context.appColors.textSecondary
                      : AppColors.warning,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                campaign.needs.map((need) => need.name).join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              CampaignProgress(campaign: campaign),
              if (campaign.hasPendingWrites) ...[
                const SizedBox(height: 8),
                Text(
                  'Pendiente de sincronización',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.warning),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.closed});

  final bool closed;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: (closed ? context.appColors.textSecondary : AppColors.success)
          .withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      closed ? 'Cerrada' : 'Activa',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: closed ? context.appColors.textSecondary : AppColors.success,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.appColors.border,
    child: const Center(child: Icon(Icons.image_not_supported_outlined)),
  );
}

class _CampaignError extends StatelessWidget {
  const _CampaignError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('No pudimos cargar las campañas.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}

String _remainingLabel(int days) =>
    days == 1 ? 'Queda 1 día' : 'Quedan $days días';
