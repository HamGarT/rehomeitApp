import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/domain/publication.dart';
import '../data/delivery_repository.dart';
import '../domain/delivery_draft.dart';

final volunteerCommitmentsProvider =
    StreamProvider.family<List<Publication>, String>((ref, userId) {
      return ref.watch(deliveryRepositoryProvider).watchCommitments(userId);
    });

final deliveryEvidenceUrlProvider = FutureProvider.family<String, String>((
  ref,
  storagePath,
) {
  return ref.watch(deliveryRepositoryProvider).evidenceUrl(storagePath);
});

final deliveryControllerProvider =
    NotifierProvider<DeliveryController, AsyncValue<void>>(
      DeliveryController.new,
    );

/// Resultado de registrar la entrega: el envío logrado o pendiente, o el
/// mensaje de error. [photoRejected] distingue el rechazo de la evidencia (D21).
typedef RegisterDeliveryOutcome = ({
  String? error,
  DeliverySubmissionResult? result,
  bool photoRejected,
});

class DeliveryController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> assume(Publication publication, String volunteerId) {
    return _run(
      () => ref
          .read(deliveryRepositoryProvider)
          .assumePickup(publication: publication, volunteerId: volunteerId),
    );
  }

  Future<String?> release(Publication publication, String actorId) {
    return _run(
      () => ref
          .read(deliveryRepositoryProvider)
          .releaseCommitment(publication: publication, actorId: actorId),
    );
  }

  Future<String?> confirmHandoff(Publication publication, String ownerId) {
    return _run(
      () => ref
          .read(deliveryRepositoryProvider)
          .confirmHandoff(publication: publication, ownerId: ownerId),
    );
  }

  Future<String?> confirmClose(Publication publication, String ownerId) {
    return _run(
      () => ref
          .read(deliveryRepositoryProvider)
          .confirmClose(publication: publication, ownerId: ownerId),
    );
  }

  Future<RegisterDeliveryOutcome> register({
    required Publication publication,
    required String userId,
    required DeliveryDraft draft,
  }) async {
    if (state.isLoading) {
      return (
        error: 'Hay otra operación en curso.',
        result: null,
        photoRejected: false,
      );
    }
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(deliveryRepositoryProvider)
          .registerDelivery(
            publication: publication,
            userId: userId,
            draft: draft,
          );
      state = const AsyncData(null);
      return (error: null, result: result, photoRejected: false);
    } on DeliveryFailure catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return (
        error: error.message,
        result: null,
        photoRejected: error.photoRejected,
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return (
        error: 'No se pudo registrar la entrega.',
        result: null,
        photoRejected: false,
      );
    }
  }

  Future<String?> _run(Future<void> Function() operation) async {
    if (state.isLoading) return 'Hay otra operación en curso.';
    state = const AsyncLoading();
    try {
      await operation();
      state = const AsyncData(null);
      return null;
    } on DeliveryFailure catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return error.message;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return 'No se pudo completar la operación.';
    }
  }
}
