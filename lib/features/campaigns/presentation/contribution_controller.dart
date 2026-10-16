import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/contribution_repository.dart';
import '../domain/campaign.dart';
import '../domain/contribution.dart';

final contributionsByContributorProvider =
    StreamProvider.family<List<Contribution>, String>((ref, contributorId) {
      return ref
          .watch(contributionRepositoryProvider)
          .watchByContributor(contributorId);
    });

final pendingContributionsByOrganizationProvider =
    StreamProvider.family<List<Contribution>, String>((ref, organizationId) {
      return ref
          .watch(contributionRepositoryProvider)
          .watchPendingByOrganization(organizationId);
    });

final contributionControllerProvider =
    NotifierProvider<ContributionController, AsyncValue<void>>(
      ContributionController.new,
    );

class ContributionController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> register({
    required Campaign campaign,
    required CampaignNeed need,
    required int quantity,
    required String contributorId,
  }) => _run(
    () => ref
        .read(contributionRepositoryProvider)
        .register(
          campaign: campaign,
          need: need,
          quantity: quantity,
          contributorId: contributorId,
        ),
  );

  Future<String?> confirm({
    required Contribution contribution,
    required String organizationId,
  }) => _run(
    () => ref
        .read(contributionRepositoryProvider)
        .confirm(contribution: contribution, organizationId: organizationId),
  );

  Future<String?> reject({
    required Contribution contribution,
    required String organizationId,
    required String reason,
  }) => _run(
    () => ref
        .read(contributionRepositoryProvider)
        .reject(
          contribution: contribution,
          organizationId: organizationId,
          reason: reason,
        ),
  );

  /// No pasa por [_run]: es una ronda de avisos de fondo (HU17-8) que no
  /// debe bloquear los botones ni mostrar error si algo no llega.
  Future<void> notifySummaryPublished({
    required Campaign campaign,
    required String actorId,
    required bool asAdmin,
  }) => ref
      .read(contributionRepositoryProvider)
      .notifySummaryPublished(
        campaign: campaign,
        actorId: actorId,
        asAdmin: asAdmin,
      );

  Future<String?> _run(Future<void> Function() operation) async {
    if (state.isLoading) return 'Hay otra operación en curso.';
    state = const AsyncLoading();
    try {
      await operation();
      state = const AsyncData(null);
      return null;
    } on ContributionFailure catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return error.message;
    }
  }
}
