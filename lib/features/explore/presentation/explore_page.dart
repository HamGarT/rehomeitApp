import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/cajamarca_districts.dart';
import '../../../shared/domain/publication.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/choice_sheet.dart';
import '../../../shared/widgets/mascot.dart';
import '../../../shared/widgets/publication_image.dart';
import '../domain/explore_filters.dart';
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

  bool _hasActiveFilters(ExploreFilters filters) {
    return filters.mode != null ||
        filters.district != null ||
        filters.search.trim().isNotEmpty;
  }

  void _clearFilters() {
    final controller = ref.read(exploreFiltersProvider.notifier);
    _searchController.clear();
    controller.updateSearch('');
    controller.selectMode(null);
    controller.selectDistrict(null);
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
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      onChanged: controller.updateSearch,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: '¿Qué necesitas? Ropa, muebles, libros...',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // La fila ocupa todo el ancho y lleva el margen por dentro:
                  // en reposo los chips alinean con el buscador y al
                  // desplazarse salen por el borde de la pantalla, no por el
                  // del buscador.
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      spacing: 8,
                      children: [
                        AppChip(
                          label: 'Todo',
                          selected: filters.mode == null,
                          onTap: () => controller.selectMode(null),
                        ),
                        AppChip(
                          label: 'Donación',
                          selected: filters.mode == PublicationMode.donation,
                          onTap: () =>
                              controller.selectMode(PublicationMode.donation),
                        ),
                        AppChip(
                          label: 'Intercambio',
                          selected: filters.mode == PublicationMode.exchange,
                          onTap: () =>
                              controller.selectMode(PublicationMode.exchange),
                        ),
                        _DistrictChip(
                          district: filters.district,
                          onSelect: controller.selectDistrict,
                        ),
                      ],
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
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyResults(
                    filtered: _hasActiveFilters(filters),
                    onClearFilters: _clearFilters,
                  ),
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

/// Filtro de distrito en la misma fila que los de modalidad. Tocar el chip
/// abre la hoja; con un distrito elegido, la X lo limpia sin abrirla.
class _DistrictChip extends StatelessWidget {
  const _DistrictChip({required this.district, required this.onSelect});

  static const _all = '';

  final String? district;
  final void Function(String?) onSelect;

  Future<void> _open(BuildContext context) async {
    final chosen = await showChoiceSheet<String>(
      context,
      title: 'Distrito',
      selected: district ?? _all,
      options: [
        const ChoiceOption(value: _all, label: 'Todos los distritos'),
        for (final name in CajamarcaDistricts.all)
          ChoiceOption(value: name, label: name),
      ],
    );
    if (chosen == null) return;
    onSelect(chosen == _all ? null : chosen);
  }

  @override
  Widget build(BuildContext context) {
    final selected = district != null;
    return AppChip(
      label: district ?? 'Distrito',
      icon: Icons.location_on_outlined,
      selected: selected,
      onTap: () => _open(context),
      trailing: selected
          ? GestureDetector(
              onTap: () => onSelect(null),
              child: const Icon(
                Icons.close,
                size: 16,
                color: AppColors.textPrimary,
              ),
            )
          : const Icon(
              Icons.expand_more,
              size: 18,
              color: AppColors.textSecondary,
            ),
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

/// Al arrancar, Firestore emite primero el snapshot de caché y enseguida el
/// del servidor. El aviso espera a que el estado de caché se sostenga; si el
/// servidor responde antes, el widget se descarta sin haberse mostrado.
class _OfflineNotice extends StatefulWidget {
  const _OfflineNotice();

  static const _grace = Duration(seconds: 2);

  @override
  State<_OfflineNotice> createState() => _OfflineNoticeState();
}

class _OfflineNoticeState extends State<_OfflineNotice> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_OfflineNotice._grace, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: !_visible
          ? const SizedBox(width: double.infinity)
          : Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(14),
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
            ),
    );
  }
}

/// Distingue "no hay nada todavía" de "nada coincide con los filtros": el
/// primero invita a publicar, el segundo ofrece limpiar los filtros.
class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.filtered, required this.onClearFilters});

  final bool filtered;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 16, 32, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Mascot(pose: MascotPose.wave, height: 150),
            const SizedBox(height: 18),
            Text(
              filtered ? 'Nada por aquí' : 'Todavía no hay publicaciones',
              textAlign: TextAlign.center,
              style: texts.titleLarge?.copyWith(
                fontFamily: 'FreckleFace',
                fontSize: 28,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              filtered
                  ? 'Ninguna publicación coincide con lo que buscas. Prueba con otros filtros.'
                  : 'Sé quien empiece: publica algo que ya no uses y dale un nuevo hogar.',
              textAlign: TextAlign.center,
              style: texts.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (filtered) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onClearFilters,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Quitar filtros'),
              ),
            ],
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
            const Mascot(pose: MascotPose.box, height: 130),
            const SizedBox(height: 16),
            const Text(
              'No pudimos cargar las publicaciones. Revisa tu conexión.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
