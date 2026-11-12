import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/domain/publication.dart';
import '../../explore/domain/explore_filters.dart';
import '../../explore/presentation/explore_controller.dart';
import 'widgets/feed_filters.dart';
import 'widgets/feed_states.dart';
import 'widgets/rehomed_strip.dart';

/// Todos los bienes ya entregados, en cuadrícula y con los filtros de Inicio.
/// Solo se llega desde "Ver todos" en la franja de Inicio.
///
/// Los filtros son propios de esta pantalla: compartirlos con el feed haría
/// que elegir una categoría aquí cambiara lo que se ve al volver a Inicio.
class RehomedPage extends ConsumerStatefulWidget {
  const RehomedPage({super.key});

  @override
  ConsumerState<RehomedPage> createState() => _RehomedPageState();
}

class _RehomedPageState extends ConsumerState<RehomedPage> {
  static const _columns = 2;

  /// Alto sobre ancho de cada celda: foto cuadrada más dos líneas de texto.
  static const _cardAspectRatio = 0.74;

  final _searchController = TextEditingController();
  ExploreFilters _filters = const ExploreFilters();
  bool _searchOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchController.clear();
        _filters = _filters.copyWith(search: '');
      }
    });
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() => _filters = const ExploreFilters());
  }

  @override
  Widget build(BuildContext context) {
    final rehomed = ref.watch(rehomedArchiveProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ya encontraron hogar'),
        actions: [
          IconButton(
            key: const Key('rehomed-search-toggle'),
            tooltip: _searchOpen ? 'Cerrar búsqueda' : 'Buscar',
            onPressed: _toggleSearch,
            icon: Icon(_searchOpen ? Icons.close : Icons.search),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          if (_searchOpen)
            SliverToBoxAdapter(
              child: FeedSearchField(
                controller: _searchController,
                onChanged: (value) =>
                    setState(() => _filters = _filters.copyWith(search: value)),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: FeedFilterChips(
                filters: _filters,
                onModeSelected: (mode) => setState(
                  () => _filters = _filters.copyWith(
                    mode: mode,
                    clearMode: mode == null,
                  ),
                ),
                onDistrictSelected: (district) => setState(
                  () => _filters = _filters.copyWith(
                    district: district,
                    clearDistrict: district == null,
                  ),
                ),
                onCategorySelected: (category) => setState(
                  () => _filters = _filters.copyWith(
                    category: category,
                    clearCategory: category == null,
                  ),
                ),
              ),
            ),
          ),
          ...rehomed.when(
            loading: () => const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (_, _) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: FeedLoadError(
                  onRetry: () => ref.invalidate(rehomedArchiveProvider),
                ),
              ),
            ],
            data: (items) => _results(context, items),
          ),
        ],
      ),
    );
  }

  List<Widget> _results(BuildContext context, List<Publication> items) {
    final visible = filterAndSortPublications(
      items,
      _filters,
      onlyPublished: false,
    );
    if (visible.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _filters.isActive
              ? FeedEmptyResults(onClearFilters: _clearFilters)
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Todavía no hay bienes entregados.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: context.appColors.textSecondary),
                    ),
                  ),
                ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
            childAspectRatio: _cardAspectRatio,
          ),
          itemCount: visible.length,
          itemBuilder: (context, index) =>
              RehomedCard(publication: visible[index]),
        ),
      ),
    ];
  }
}
