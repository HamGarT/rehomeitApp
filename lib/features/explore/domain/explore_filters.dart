import '../../../shared/domain/publication.dart';

class ExploreFilters {
  const ExploreFilters({
    this.mode,
    this.district,
    this.category,
    this.search = '',
  });

  final PublicationMode? mode;
  final String? district;
  final String? category;
  final String search;

  bool get isActive =>
      mode != null ||
      district != null ||
      category != null ||
      search.trim().isNotEmpty;

  ExploreFilters copyWith({
    PublicationMode? mode,
    bool clearMode = false,
    String? district,
    bool clearDistrict = false,
    String? category,
    bool clearCategory = false,
    String? search,
  }) {
    return ExploreFilters(
      mode: clearMode ? null : mode ?? this.mode,
      district: clearDistrict ? null : district ?? this.district,
      category: clearCategory ? null : category ?? this.category,
      search: search ?? this.search,
    );
  }
}

/// [onlyPublished] es el caso del feed, que solo ofrece lo disponible. La
/// pantalla de bienes entregados lo desactiva porque su consulta ya trae
/// únicamente los estados finales.
List<Publication> filterAndSortPublications(
  Iterable<Publication> publications,
  ExploreFilters filters, {
  bool onlyPublished = true,
}) {
  final search = _searchable(filters.search);
  final result = publications.where((publication) {
    if (onlyPublished && publication.status != PublicationStatus.published) {
      return false;
    }
    if (filters.mode != null && publication.mode != filters.mode) return false;
    if (filters.district != null && publication.district != filters.district) {
      return false;
    }
    if (filters.category != null && publication.category != filters.category) {
      return false;
    }
    return search.isEmpty ||
        _searchable(publication.title).contains(search) ||
        _searchable(publication.category).contains(search);
  }).toList();

  result.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  return result;
}

const _accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u'};

/// Quien busca "electrodomesticos" sin tilde espera encontrar la categoría
/// "Electrodomésticos". La ñ se conserva porque distingue palabras.
String _searchable(String text) {
  return text.trim().toLowerCase().replaceAllMapped(
    RegExp('[áéíóúü]'),
    (match) => _accents[match[0]]!,
  );
}
