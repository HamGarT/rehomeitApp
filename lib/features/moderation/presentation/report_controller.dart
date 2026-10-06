import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/domain/publication.dart';
import '../data/moderation_repository.dart';
import '../domain/publication_report.dart';

final reportControllerProvider =
    NotifierProvider<ReportController, AsyncValue<void>>(ReportController.new);

class ReportController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Devuelve `null` si el reporte quedó registrado o el mensaje con el que
  /// falló, para que la hoja lo muestre sin salir de ella.
  Future<String?> report({
    required Publication publication,
    required String reporterId,
    required ReportReason reason,
    String? comment,
  }) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    try {
      await ref
          .read(moderationRepositoryProvider)
          .report(
            publication: publication,
            reporterId: reporterId,
            reason: reason,
            comment: comment,
          );
      state = const AsyncData(null);
      return null;
    } on ReportFailure catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return error.message;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return 'No se pudo enviar el reporte. Inténtalo nuevamente.';
    }
  }
}
