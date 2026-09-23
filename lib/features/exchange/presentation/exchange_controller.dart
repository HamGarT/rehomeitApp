import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/domain/publication.dart';
import '../data/exchange_repository.dart';
import '../domain/exchange_proposal.dart';

final eligibleExchangePublicationsProvider =
    StreamProvider.family<List<Publication>, String>((ref, userId) {
      return ref
          .watch(exchangeRepositoryProvider)
          .watchEligiblePublications(userId);
    });

final userExchangeProposalsProvider =
    StreamProvider.family<List<ExchangeProposal>, String>((ref, userId) {
      return ref.watch(exchangeRepositoryProvider).watchUserProposals(userId);
    });

final exchangeClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(minutes: 1),
    (_) => DateTime.now(),
  );
});

final exchangeControllerProvider =
    NotifierProvider<ExchangeController, AsyncValue<void>>(
      ExchangeController.new,
    );

class ExchangeController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> propose({
    required String requestedPublicationId,
    required String offeredPublicationId,
    required String proposerId,
  }) {
    return _run(
      () => ref
          .read(exchangeRepositoryProvider)
          .propose(
            requestedPublicationId: requestedPublicationId,
            offeredPublicationId: offeredPublicationId,
            proposerId: proposerId,
          ),
    );
  }

  Future<String?> respond({
    required String proposalId,
    required String ownerId,
    required bool accept,
  }) {
    return _run(
      () => ref
          .read(exchangeRepositoryProvider)
          .respond(proposalId: proposalId, ownerId: ownerId, accept: accept),
    );
  }

  Future<String?> confirmReceipt({
    required String proposalId,
    required String userId,
  }) {
    return _run(
      () => ref
          .read(exchangeRepositoryProvider)
          .confirmReceipt(proposalId: proposalId, userId: userId),
    );
  }

  Future<String?> _run(Future<void> Function() operation) async {
    if (state.isLoading) return 'Hay otra operación en curso.';
    state = const AsyncLoading();
    try {
      await operation();
      state = const AsyncData(null);
      return null;
    } on ExchangeFailure catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return error.message;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return 'No se pudo completar la operación. Inténtalo nuevamente.';
    }
  }
}
