import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/domain/publication.dart';
import '../domain/public_profile.dart';

final exploreRepositoryProvider = Provider<ExploreRepository>((ref) {
  return ExploreRepository(FirebaseFirestore.instance);
});

class ExploreFeed {
  const ExploreFeed({required this.publications, required this.isFromCache});

  final List<Publication> publications;
  final bool isFromCache;
}

class ExploreRepository {
  ExploreRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<ExploreFeed> watchAvailable({
    PublicationMode? mode,
    String? district,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('publicaciones')
        .where('status', isEqualTo: PublicationStatus.published.wireValue);

    if (mode != null) {
      query = query.where('mode', isEqualTo: mode.wireValue);
    }
    if (district != null) {
      query = query.where('district', isEqualTo: district);
    }

    return query
        .orderBy('publishedAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => ExploreFeed(
            publications: snapshot.docs
                .map((doc) => Publication.fromMap(doc.id, doc.data()))
                .toList(growable: false),
            isFromCache: snapshot.metadata.isFromCache,
          ),
        );
  }

  Stream<Publication?> watchPublication(String publicationId) {
    return _firestore
        .collection('publicaciones')
        .doc(publicationId)
        .snapshots(includeMetadataChanges: true)
        .map(
          (document) => document.exists
              ? Publication.fromMap(document.id, document.data()!)
              : null,
        );
  }

  Stream<PublicProfile?> watchPublicProfile(String userId) {
    return _firestore
        .collection('perfiles')
        .doc(userId)
        .snapshots()
        .map(
          (document) => document.exists
              ? PublicProfile.fromMap(document.id, document.data()!)
              : null,
        );
  }
}
