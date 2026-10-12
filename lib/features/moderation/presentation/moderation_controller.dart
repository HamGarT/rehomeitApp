import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/domain/publication.dart';
import '../data/moderation_repository.dart';
import '../domain/publication_report.dart';

/// Si la sesión tiene rol de administrador. Decide si el perfil muestra la
/// sección de moderación; las reglas deciden lo demás.
final isAdminProvider = StreamProvider.family<bool, String>((ref, userId) {
  return ref.watch(moderationRepositoryProvider).watchIsAdmin(userId);
});

/// Solo lo observan administradores: para cualquier otra cuenta la consulta
/// termina en permiso denegado.
final pendingReportsProvider = StreamProvider<List<PublicationReport>>((ref) {
  return ref.watch(moderationRepositoryProvider).watchPendingReports();
});

final moderationControllerProvider =
    NotifierProvider<ModerationController, AsyncValue<void>>(
      ModerationController.new,
    );

class ModerationController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> dismiss({
    required PublicationReport report,
    required Publication publication,
    required String adminId,
  }) {
    return _run(
      () => ref
          .read(moderationRepositoryProvider)
          .dismiss(report: report, publication: publication, adminId: adminId),
    );
  }

  Future<String?> removePublication({
    required PublicationReport report,
    required Publication publication,
    required String adminId,
  }) {
    return _run(
      () => ref
          .read(moderationRepositoryProvider)
          .removePublication(
            report: report,
            publication: publication,
            adminId: adminId,
          ),
    );
  }

  Future<String?> resolveAlreadyRemoved({
    required PublicationReport report,
    required Publication publication,
    required String adminId,
  }) {
    return _run(
      () => ref
          .read(moderationRepositoryProvider)
          .resolveAlreadyRemoved(
            report: report,
            publication: publication,
            adminId: adminId,
          ),
    );
  }

  /// Devuelve `null` si la operación terminó o el mensaje con el que falló.
  Future<String?> _run(Future<void> Function() operation) async {
    if (state.isLoading) return 'Hay otra operación en curso.';
    state = const AsyncLoading();
    try {
      await operation();
      state = const AsyncData(null);
      return null;
    } on ModerationFailure catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return error.message;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return 'No se pudo resolver el reporte. Inténtalo nuevamente.';
    }
  }
}
