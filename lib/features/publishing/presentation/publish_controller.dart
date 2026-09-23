import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/publishing_repository.dart';
import '../domain/publish_draft.dart';

final publishControllerProvider =
    NotifierProvider<PublishController, AsyncValue<void>>(
      PublishController.new,
    );

class PublishController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> publish({
    required PublishDraft draft,
    required String authorId,
  }) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    try {
      await ref
          .read(publishingRepositoryProvider)
          .publish(draft: draft, authorId: authorId);
      state = const AsyncData(null);
      return null;
    } on PublishingFailure catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return error.message;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return 'No se pudo registrar la publicación. Tus datos se conservaron.';
    }
  }
}
