import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_repository.dart';
import '../domain/admin_user.dart';

final adminUsersProvider = StreamProvider<List<AdminUser>>((ref) {
  return ref.watch(adminRepositoryProvider).watchUsers();
});

final adminControllerProvider =
    NotifierProvider<AdminController, AsyncValue<void>>(AdminController.new);

class AdminController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> verifyAccount({
    required String userId,
    required String adminId,
  }) => _run(
    () => ref
        .read(adminRepositoryProvider)
        .verifyAccount(userId: userId, adminId: adminId),
  );

  Future<String?> blockAccount({
    required String userId,
    required String adminId,
    required String reason,
  }) => _run(
    () => ref
        .read(adminRepositoryProvider)
        .blockAccount(userId: userId, adminId: adminId, reason: reason),
  );

  Future<String?> retireAccount({
    required String userId,
    required String adminId,
    required String reason,
  }) => _run(
    () => ref
        .read(adminRepositoryProvider)
        .retireAccount(userId: userId, adminId: adminId, reason: reason),
  );

  Future<String?> reactivateAccount({
    required String userId,
    required String adminId,
  }) => _run(
    () => ref
        .read(adminRepositoryProvider)
        .reactivateAccount(userId: userId, adminId: adminId),
  );

  Future<String?> notifyInactivityRetirement({
    required String userId,
    required String adminId,
  }) => _run(
    () => ref
        .read(adminRepositoryProvider)
        .notifyInactivityRetirement(userId: userId, adminId: adminId),
  );

  Future<String?> verifyCampaign({
    required String campaignId,
    required String adminId,
  }) => _run(
    () => ref
        .read(adminRepositoryProvider)
        .verifyCampaign(campaignId: campaignId, adminId: adminId),
  );

  Future<String?> _run(Future<void> Function() operation) async {
    if (state.isLoading) return 'Hay otra operación en curso.';
    state = const AsyncLoading();
    try {
      await operation();
      state = const AsyncData(null);
      return null;
    } on AdminFailure catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return error.message;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return 'No se pudo completar la acción. Inténtalo nuevamente.';
    }
  }
}
