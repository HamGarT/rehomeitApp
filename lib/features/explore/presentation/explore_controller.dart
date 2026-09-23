import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/domain/publication.dart';
import '../data/explore_repository.dart';
import '../domain/explore_filters.dart';
import '../domain/public_profile.dart';

final exploreFiltersProvider =
    NotifierProvider<ExploreFiltersController, ExploreFilters>(
      ExploreFiltersController.new,
    );

class ExploreFiltersController extends Notifier<ExploreFilters> {
  @override
  ExploreFilters build() => const ExploreFilters();

  void selectMode(PublicationMode? mode) {
    state = state.copyWith(mode: mode, clearMode: mode == null);
  }

  void selectDistrict(String? district) {
    state = state.copyWith(district: district, clearDistrict: district == null);
  }

  void updateSearch(String search) {
    state = state.copyWith(search: search);
  }
}

typedef RemoteExploreFilters = ({PublicationMode? mode, String? district});

final remoteExploreFeedProvider =
    StreamProvider.family<ExploreFeed, RemoteExploreFilters>((ref, filters) {
      return ref
          .watch(exploreRepositoryProvider)
          .watchAvailable(mode: filters.mode, district: filters.district);
    });

final exploreFeedProvider = Provider<AsyncValue<ExploreFeed>>((ref) {
  final filters = ref.watch(exploreFiltersProvider);
  final remote = ref.watch(
    remoteExploreFeedProvider((mode: filters.mode, district: filters.district)),
  );
  return remote.whenData(
    (feed) => ExploreFeed(
      publications: filterAndSortPublications(feed.publications, filters),
      isFromCache: feed.isFromCache,
    ),
  );
});

final publicationDetailProvider = StreamProvider.family<Publication?, String>((
  ref,
  publicationId,
) {
  return ref.watch(exploreRepositoryProvider).watchPublication(publicationId);
});

final publicProfileProvider = StreamProvider.family<PublicProfile?, String>((
  ref,
  userId,
) {
  return ref.watch(exploreRepositoryProvider).watchPublicProfile(userId);
});
