import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../app/theme.dart';
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

OutlineInputBorder _searchBorder(Color color, double width) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: color, width: width),
  );
}

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
                      decoration: InputDecoration(
                        hintText: '¿Qué necesitas? Ropa, muebles, libros...',
                        hintStyle: TextStyle(color: Colors.grey.shade600),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.black,
                        ),
                        border: _searchBorder(Colors.black, 1),
                        enabledBorder: _searchBorder(Colors.black, 1),
                        focusedBorder: _searchBorder(Colors.black, 2),
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
              child: Icon(
                Icons.close,
                size: 16,
                color: context.appColors.textPrimary,
              ),
            )
          : Icon(
              Icons.expand_more,
              size: 18,
              color: context.appColors.textSecondary,
            ),
    );
  }
}

class _PublicationCard extends StatelessWidget {
  const _PublicationCard({required this.publication});

  final Publication publication;

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;
    final scrim = palette.imageScrim;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(32);

    // Una sombra negra no se ve sobre un fondo negro, así que en oscuro la
    // sombra sube en tono: es un brillo tenue, no un hundimiento.
    final shadowColor = isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: isDark ? 0.06 : 0.10),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        // Sin borde: el contorno cálido de `AppColors.border` ensuciaba la
        // foto. La sombra de abajo es lo que separa la tarjeta del fondo.
        shape: RoundedRectangleBorder(borderRadius: radius),
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PublicationDetailPage(initial: publication),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Background Image filling the card
              PublicationImage(
                url: publication.images.isEmpty
                    ? null
                    : publication.images.first,
              ),

              // 2. Scrim gradient at the bottom for text readability. It stops
              // short of opaque on purpose: enough contrast to read the title
              // over any photo, but the image stays visible instead of being
              // replaced by a solid block.
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        scrim.withValues(alpha: 0),
                        scrim.withValues(alpha: 0.45),
                        scrim.withValues(alpha: 0.85),
                      ],
                      stops: const [0, 0.55, 1],
                    ),
                  ),
                ),
              ),

              // 3. Top Left Badge (Donación)
              Positioned(
                top: 16,
                left: 10,
                child: PublicationModeBadge(mode: publication.mode),
              ),

              // 4. Top Right Yellow Action Button
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.accent, // Yellow matching the image
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_outward,
                    color: Colors.black,
                    size: 24,
                  ),
                ),
              ),

              // 5. Bottom Text Information
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 16, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        publication.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          // Va sobre el velo, no sobre la superficie: en oscuro el
                          // velo es negro y el título tiene que volverse blanco.
                          color: context.appColors.onImageScrim,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 18,
                            // Se apoya sobre el velo, igual que el título: un
                            // gris fijo se perdía contra el velo negro de oscuro.
                            color: context.appColors.onImageScrim.withValues(
                              alpha: 0.72,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              publication.district,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: context.appColors.onImageScrim
                                        .withValues(alpha: 0.72),
                                    fontSize: 12,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
                color: context.appColors.textSecondary,
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
