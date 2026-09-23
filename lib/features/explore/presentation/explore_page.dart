import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/cajamarca_districts.dart';
import '../../../shared/domain/publication.dart';
import '../../../shared/widgets/publication_image.dart';
import 'explore_controller.dart';
import 'publication_detail_page.dart';
import 'widgets/publication_mode_badge.dart';

class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(exploreFiltersProvider);
    final feed = ref.watch(exploreFeedProvider);
    final controller = ref.read(exploreFiltersProvider.notifier);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(remoteExploreFeedProvider);
        await ref.read(
          remoteExploreFeedProvider((
            mode: filters.mode,
            district: filters.district,
          )).future,
        );
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: controller.updateSearch,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Buscar por título',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _ModeChip(
                          label: 'Todo',
                          selected: filters.mode == null,
                          onSelected: () => controller.selectMode(null),
                        ),
                        const SizedBox(width: 8),
                        _ModeChip(
                          label: 'Donación',
                          selected: filters.mode == PublicationMode.donation,
                          onSelected: () =>
                              controller.selectMode(PublicationMode.donation),
                        ),
                        const SizedBox(width: 8),
                        _ModeChip(
                          label: 'Intercambio',
                          selected: filters.mode == PublicationMode.exchange,
                          onSelected: () =>
                              controller.selectMode(PublicationMode.exchange),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(filters.district),
                    initialValue: filters.district,
                    decoration: const InputDecoration(
                      labelText: 'Distrito',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Todos los distritos'),
                      ),
                      for (final district in CajamarcaDistricts.all)
                        DropdownMenuItem(
                          value: district,
                          child: Text(district),
                        ),
                    ],
                    onChanged: (value) => controller.selectDistrict(
                      value == null || value.isEmpty ? null : value,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...feed.when(
            loading: () => const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (error, stackTrace) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ExploreError(
                  onRetry: () => ref.invalidate(remoteExploreFeedProvider),
                ),
              ),
            ],
            data: (result) => [
              if (result.isFromCache)
                const SliverToBoxAdapter(child: _OfflineNotice()),
              if (result.publications.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyResults(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.crossAxisExtent;
                      final columns = width >= 1100
                          ? 5
                          : width >= 800
                          ? 4
                          : width >= 540
                          ? 3
                          : 2;
                      return SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.7,
                        ),
                        itemCount: result.publications.length,
                        itemBuilder: (context, index) => _PublicationCard(
                          publication: result.publications[index],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _PublicationCard extends StatelessWidget {
  const _PublicationCard({required this.publication});

  final Publication publication;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PublicationDetailPage(initial: publication),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PublicationImage(
                    url: publication.images.isEmpty
                        ? null
                        : publication.images.first,
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: PublicationModeBadge(mode: publication.mode),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    publication.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          publication.district,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: AppColors.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mostrando datos guardados. El listado puede no estar actualizado.',
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 52,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 14),
            Text(
              'No encontramos publicaciones con esos filtros.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreError extends StatelessWidget {
  const _ExploreError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            const Text(
              'No pudimos cargar las publicaciones. Revisa tu conexión.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
