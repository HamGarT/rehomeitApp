import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../explore/data/explore_repository.dart';

final publicationJourneyProvider =
    StreamProvider.family<PublicationSnapshot, String>((ref, publicationId) {
      return ref
          .watch(exploreRepositoryProvider)
          .watchPublicationSource(publicationId);
    });
