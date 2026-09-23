import '../../../shared/domain/publication.dart';

class ExploreFilters {
  const ExploreFilters({this.mode, this.district, this.search = ''});

  final PublicationMode? mode;
  final String? district;
  final String search;

  ExploreFilters copyWith({
    PublicationMode? mode,
    bool clearMode = false,
    String? district,
    bool clearDistrict = false,
    String? search,
  }) {
    return ExploreFilters(
      mode: clearMode ? null : mode ?? this.mode,
      district: clearDistrict ? null : district ?? this.district,
      search: search ?? this.search,
    );
  }
}

List<Publication> filterAndSortPublications(
  Iterable<Publication> publications,
  ExploreFilters filters,
) {
  final search = filters.search.trim().toLowerCase();
  final result = publications.where((publication) {
    if (publication.status != PublicationStatus.published) return false;
    if (filters.mode != null && publication.mode != filters.mode) return false;
    if (filters.district != null && publication.district != filters.district) {
      return false;
    }
    return search.isEmpty || publication.title.toLowerCase().contains(search);
  }).toList();

  result.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  return result;
}
