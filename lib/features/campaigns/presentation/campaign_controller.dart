import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/campaign_repository.dart';
import '../domain/campaign.dart';
import '../domain/campaign_draft.dart';

final campaignAccessProvider = StreamProvider.family<CampaignAccess, String>((
  ref,
  userId,
) {
  return ref.watch(campaignRepositoryProvider).watchAccess(userId);
});

final campaignsProvider = StreamProvider<List<Campaign>>((ref) {
  return ref.watch(campaignRepositoryProvider).watchCampaigns();
});

/// Reevalúa el estado efectivo aunque Firestore no emita justo al vencer.
final campaignClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now().toUtc();
  yield* Stream<DateTime>.periodic(
    const Duration(minutes: 1),
    (_) => DateTime.now().toUtc(),
  );
});

final campaignProvider = StreamProvider.family<Campaign?, String>((ref, id) {
  return ref.watch(campaignRepositoryProvider).watchCampaign(id);
});

final ownCampaignsProvider = StreamProvider.family<List<Campaign>, String>((
  ref,
  organizationId,
) {
  return ref
      .watch(campaignRepositoryProvider)
      .watchOwnCampaigns(organizationId);
});

final campaignControllerProvider =
    NotifierProvider<CampaignController, AsyncValue<void>>(
      CampaignController.new,
    );

class CampaignController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<({String? id, String? error})> create({
    required CampaignDraft draft,
    required String organizationId,
    required String organizationName,
  }) async {
    if (state.isLoading) {
      return (id: null, error: 'Hay otra operación en curso.');
    }
    state = const AsyncLoading();
    try {
      final id = await ref
          .read(campaignRepositoryProvider)
          .create(
            draft: draft,
            organizationId: organizationId,
            organizationName: organizationName,
          );
      state = const AsyncData(null);
      return (id: id, error: null);
    } on CampaignFailure catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return (id: null, error: error.message);
    }
  }

  Future<String?> update({
    required Campaign campaign,
    required CampaignDraft draft,
  }) => _run(
    () => ref
        .read(campaignRepositoryProvider)
        .update(campaign: campaign, draft: draft),
  );

  Future<String?> saveDestinationNote({
    required String campaignId,
    required String note,
  }) => _run(
    () => ref
        .read(campaignRepositoryProvider)
        .saveDestinationNote(campaignId: campaignId, note: note),
  );

  Future<String?> closeEarly({
    required String campaignId,
    required String closedBy,
    required String reason,
  }) => _run(
    () => ref
        .read(campaignRepositoryProvider)
        .closeEarly(campaignId: campaignId, closedBy: closedBy, reason: reason),
  );

  Future<String?> _run(Future<void> Function() operation) async {
    if (state.isLoading) return 'Hay otra operación en curso.';
    state = const AsyncLoading();
    try {
      await operation();
      state = const AsyncData(null);
      return null;
    } on CampaignFailure catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return error.message;
    }
  }
}
