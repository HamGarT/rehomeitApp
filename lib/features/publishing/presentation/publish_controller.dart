import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/publishing_repository.dart';
import '../domain/publish_draft.dart';

export '../data/publishing_repository.dart' show PublishSubmissionResult;

final publishControllerProvider =
    NotifierProvider<PublishController, AsyncValue<void>>(
      PublishController.new,
    );

/// Resultado de publicar: el envío logrado o pendiente, o el mensaje de error.
typedef PublishOutcome = ({PublishSubmissionResult? result, String? error});

class PublishController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<PublishOutcome> publish({
    required PublishDraft draft,
    required String authorId,
  }) async {
    if (state.isLoading) return (result: null, error: null);
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(publishingRepositoryProvider)
          .publish(draft: draft, authorId: authorId);
      state = const AsyncData(null);
      return (result: result, error: null);
    } on PublishingFailure catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return (result: null, error: error.message);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return (
        result: null,
        error: 'No se pudo registrar la publicación. Tus datos se conservaron.',
      );
    }
  }

  Future<String?> withdraw(String publicationId) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    try {
      await ref.read(publishingRepositoryProvider).withdraw(publicationId);
      state = const AsyncData(null);
      return null;
    } on PublishingFailure catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return error.message;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return 'No se pudo anular la publicación. Inténtalo nuevamente.';
    }
  }
}
