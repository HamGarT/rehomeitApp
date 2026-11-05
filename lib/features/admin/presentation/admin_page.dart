import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/verified_name.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../campaigns/domain/campaign.dart';
import '../../campaigns/presentation/campaign_controller.dart';
import '../../campaigns/presentation/campaign_detail_page.dart';
import '../../moderation/presentation/moderation_controller.dart';
import '../domain/admin_user.dart';
import 'admin_controller.dart';

/// Módulo de administración de cuentas y verificación de campañas.
///
/// La entrada solo aparece para administradores y las reglas de Firestore
/// vuelven a comprobar el rol en cada lectura y escritura.
class AdminPage extends ConsumerWidget {
  const AdminPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authStateProvider).value?.uid ?? '';
    final isAdmin = userId.isEmpty
        ? false
        : ref.watch(isAdminProvider(userId)).value ?? false;

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Administración')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Esta sección solo está disponible para administración.',
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administración'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Cuentas'),
              Tab(text: 'Campañas'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _UsersTab(adminId: userId),
            _CampaignsTab(adminId: userId),
          ],
        ),
      ),
    );
  }
}

enum _UserFilter { all, duplicates, inactive, blocked, retired }

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab({required this.adminId});

  final String adminId;

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  final _searchController = TextEditingController();
  var _filter = _UserFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminUsersProvider);

    return users.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _AdminError(
        message: 'No se pudieron cargar las cuentas.',
        onRetry: () => ref.invalidate(adminUsersProvider),
      ),
      data: (items) {
        final duplicateIds = _duplicateUserIds(items);
        final filtered = _filterUsers(items, duplicateIds);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Control mensual: revisar cuentas redundantes y permisos. '
                    'Las coincidencias se detectan por correo exacto; el UID y '
                    'el correo de una cuenta no se reasignan. '
                    'Control semestral: revisar cuentas con más de 12 meses '
                    'sin actividad, avisar antes de retirarlas.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar por nombre o correo',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final filter in _UserFilter.values)
                    AppChip(
                      label: _filterLabel(filter),
                      selected: _filter == filter,
                      onTap: () => setState(() => _filter = filter),
                    ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No hay cuentas que coincidan con el filtro.',
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(adminUsersProvider);
                        await ref.read(adminUsersProvider.future);
                      },
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _UserTile(
                          user: filtered[index],
                          adminId: widget.adminId,
                          isDuplicate: duplicateIds.contains(
                            filtered[index].id,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  List<AdminUser> _filterUsers(
    List<AdminUser> users,
    Set<String> duplicateIds,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    return users.where((user) {
      final matchesFilter = switch (_filter) {
        _UserFilter.all => true,
        _UserFilter.duplicates => duplicateIds.contains(user.id),
        _UserFilter.inactive => user.isInactive(),
        _UserFilter.blocked => user.status == AccountStatus.blocked,
        _UserFilter.retired => user.status == AccountStatus.retired,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return user.fullName.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query);
    }).toList();
  }

  Set<String> _duplicateUserIds(List<AdminUser> users) {
    final byEmail = <String, List<AdminUser>>{};
    for (final user in users) {
      final email = user.normalizedEmail;
      if (email.isEmpty) continue;
      byEmail.putIfAbsent(email, () => []).add(user);
    }
    return {
      for (final group in byEmail.values)
        if (group.length > 1) ...group.map((user) => user.id),
    };
  }
}

String _filterLabel(_UserFilter filter) => switch (filter) {
  _UserFilter.all => 'Todas',
  _UserFilter.duplicates => 'Posibles duplicadas',
  _UserFilter.inactive => 'Inactivas',
  _UserFilter.blocked => 'Bloqueadas',
  _UserFilter.retired => 'Retiradas',
};

enum _UserAction { verify, block, retire, reactivate, notifyRetirement }

class _UserTile extends ConsumerWidget {
  const _UserTile({
    required this.user,
    required this.adminId,
    required this.isDuplicate,
  });

  final AdminUser user;
  final String adminId;
  final bool isDuplicate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appColors;
    final isSelf = user.id == adminId;
    final inactive = user.isInactive();
    final canRetire =
        user.status != AccountStatus.retired &&
        !(inactive && user.noticeAt == null);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              child: Text(
                user.fullName.isEmpty ? '?' : user.fullName[0].toUpperCase(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: VerifiedName(
                          name: user.fullName,
                          isVerified: user.isVerified,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (isSelf)
                        Text(
                          'Tu cuenta',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: palette.textSecondary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${user.roleLabel} · ${user.email}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: palette.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _StatusBadge(status: user.status),
                      if (isDuplicate)
                        AppBadge(
                          label: 'Correo repetido',
                          background: AppColors.warning.withValues(alpha: 0.18),
                          foreground: AppColors.warning,
                        ),
                      if (user.isVerified)
                        const AppBadge(
                          label: 'Verificada',
                          background: AppColors.accentSoft,
                          foreground: AppColors.onAccent,
                        ),
                      if (inactive) const _InactiveBadge(),
                      if (user.noticeAt != null &&
                          user.status == AccountStatus.active)
                        const _NoticeBadge(),
                    ],
                  ),
                  if (user.statusReason case final reason?)
                    if (reason.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Motivo: $reason',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  const SizedBox(height: 6),
                  Text(
                    user.lastSeenAt == null
                        ? 'Sin actividad registrada'
                        : 'Última actividad: ${timeAgo(user.lastSeenAt!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: inactive
                          ? AppColors.warning
                          : palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!isSelf)
              PopupMenuButton<_UserAction>(
                tooltip: 'Acciones de la cuenta',
                onSelected: (action) => _handleAction(context, ref, action),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _UserAction.verify,
                    child: Text(
                      user.isVerified
                          ? 'Actualizar check público'
                          : 'Marcar como verificada',
                    ),
                  ),
                  if (user.status == AccountStatus.active)
                    const PopupMenuItem(
                      value: _UserAction.block,
                      child: Text('Bloquear cuenta'),
                    ),
                  if (user.status == AccountStatus.active &&
                      user.needsRetirementNotice())
                    const PopupMenuItem(
                      value: _UserAction.notifyRetirement,
                      child: Text('Avisar retiro por inactividad'),
                    ),
                  if (canRetire)
                    PopupMenuItem(
                      value: _UserAction.retire,
                      child: Text(
                        inactive ? 'Retirar cuenta inactiva' : 'Retirar cuenta',
                      ),
                    ),
                  if (user.status != AccountStatus.active)
                    const PopupMenuItem(
                      value: _UserAction.reactivate,
                      child: Text('Reactivar cuenta'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _UserAction action,
  ) async {
    switch (action) {
      case _UserAction.verify:
        await _run(
          context,
          () => ref
              .read(adminControllerProvider.notifier)
              .verifyAccount(userId: user.id, adminId: adminId),
          success: 'Cuenta marcada como verificada.',
        );
        break;
      case _UserAction.block:
        final reason = await _askReason(
          context,
          title: 'Bloquear cuenta',
          hint: 'Explica por qué se bloquea esta cuenta.',
        );
        if (reason == null || !context.mounted) return;
        await _run(
          context,
          () => ref
              .read(adminControllerProvider.notifier)
              .blockAccount(userId: user.id, adminId: adminId, reason: reason),
          success: 'La cuenta fue bloqueada y se avisó a la persona.',
        );
        break;
      case _UserAction.retire:
        final reason = await _askReason(
          context,
          title: 'Retirar cuenta',
          hint: 'Explica por qué se retira esta cuenta.',
        );
        if (reason == null || !context.mounted) return;
        await _run(
          context,
          () => ref
              .read(adminControllerProvider.notifier)
              .retireAccount(userId: user.id, adminId: adminId, reason: reason),
          success: 'La cuenta fue retirada y se avisó a la persona.',
        );
        break;
      case _UserAction.reactivate:
        final confirmed = await showAppConfirmDialog(
          context,
          title: 'Reactivar cuenta',
          subtitle: 'La persona podrá volver a iniciar sesión.',
          confirmLabel: 'Reactivar',
          icon: Icons.lock_open_outlined,
        );
        if (!confirmed || !context.mounted) return;
        await _run(
          context,
          () => ref
              .read(adminControllerProvider.notifier)
              .reactivateAccount(userId: user.id, adminId: adminId),
          success: 'La cuenta fue reactivada.',
        );
        break;
      case _UserAction.notifyRetirement:
        final confirmed = await showAppConfirmDialog(
          context,
          title: 'Avisar retiro por inactividad',
          subtitle:
              'Se enviará una notificación antes de retirar una cuenta que '
              'lleva más de 12 meses sin actividad.',
          confirmLabel: 'Enviar aviso',
          icon: Icons.notifications_active_outlined,
        );
        if (!confirmed || !context.mounted) return;
        await _run(
          context,
          () => ref
              .read(adminControllerProvider.notifier)
              .notifyInactivityRetirement(userId: user.id, adminId: adminId),
          success: 'Aviso de retiro enviado.',
        );
        break;
    }
  }
}

class _CampaignsTab extends ConsumerWidget {
  const _CampaignsTab({required this.adminId});

  final String adminId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaigns = ref.watch(campaignsProvider);

    return campaigns.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _AdminError(
        message: 'No se pudieron cargar las campañas.',
        onRetry: () => ref.invalidate(campaignsProvider),
      ),
      data: (items) {
        final sorted = [...items]
          ..sort((a, b) {
            if (a.isVerified != b.isVerified) {
              return a.isVerified ? 1 : -1;
            }
            return a.closeAt.compareTo(b.closeAt);
          });
        final pending = sorted.where((campaign) => !campaign.isVerified).length;

        if (sorted.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Todavía no hay campañas para verificar.'),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(campaignsProvider);
            await ref.read(campaignsProvider.future);
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Text(
                  pending == 0
                      ? 'Todas las campañas están verificadas.'
                      : '$pending ${pending == 1 ? 'campaña pendiente' : 'campañas pendientes'} de verificación.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: context.appColors.textSecondary),
                );
              }
              final campaign = sorted[index - 1];
              return _CampaignVerificationTile(
                campaign: campaign,
                adminId: adminId,
              );
            },
          ),
        );
      },
    );
  }
}

class _CampaignVerificationTile extends ConsumerWidget {
  const _CampaignVerificationTile({
    required this.campaign,
    required this.adminId,
  });

  final Campaign campaign;
  final String adminId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appColors;
    final closed = campaign.isClosedAt(DateTime.now().toUtc());
    // La tarjeta abre el detalle: ahí el administrador revisa la campaña
    // completa y puede cerrarla anticipadamente (HU15-13), acción que no se
    // duplica aquí. Borrar no existe: aportes y avisos la referencian.
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => pushUnique(
          context,
          name: AppRoutes.campaign(campaign.id),
          builder: (_) => CampaignDetailPage(initial: campaign),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      campaign.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  AppBadge(
                    label: campaign.isVerified ? 'Verificada' : 'Sin verificar',
                    background: campaign.isVerified
                        ? AppColors.success.withValues(alpha: 0.18)
                        : AppColors.warning.withValues(alpha: 0.18),
                    foreground: campaign.isVerified
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  if (closed) ...[
                    const SizedBox(width: 6),
                    AppBadge(
                      label: 'Cerrada',
                      background: AppColors.error.withValues(alpha: 0.18),
                      foreground: AppColors.error,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${campaign.organizationName} · ${campaign.district}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                closed
                    ? 'Cerrada el ${formatDateTime(campaign.closeAt)} · Toca para ver el resumen'
                    : 'Cierra el ${formatDateTime(campaign.closeAt)} · Toca para ver el detalle',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: palette.textSecondary),
              ),
              if (!campaign.isVerified) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final error = await ref
                          .read(adminControllerProvider.notifier)
                          .verifyCampaign(
                            campaignId: campaign.id,
                            adminId: adminId,
                          );
                      if (!context.mounted) return;
                      showAppSnackBar(
                        context,
                        error ?? 'Campaña verificada.',
                        kind: error == null
                            ? AppSnackBarKind.success
                            : AppSnackBarKind.error,
                      );
                    },
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Verificar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final AccountStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      AccountStatus.active => (
        AppColors.success.withValues(alpha: 0.18),
        AppColors.success,
      ),
      AccountStatus.blocked => (
        AppColors.warning.withValues(alpha: 0.18),
        AppColors.warning,
      ),
      AccountStatus.retired => (
        AppColors.error.withValues(alpha: 0.18),
        AppColors.error,
      ),
    };
    return AppBadge(
      label: status.label,
      background: background,
      foreground: foreground,
    );
  }
}

class _InactiveBadge extends StatelessWidget {
  const _InactiveBadge();

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      label: 'Inactiva +12 meses',
      background: AppColors.warning.withValues(alpha: 0.12),
      foreground: AppColors.warning,
    );
  }
}

class _NoticeBadge extends StatelessWidget {
  const _NoticeBadge();

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      label: 'Aviso enviado',
      background: AppColors.warning.withValues(alpha: 0.12),
      foreground: AppColors.warning,
    );
  }
}

class _AdminError extends StatelessWidget {
  const _AdminError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

Future<String?> _askReason(
  BuildContext context, {
  required String title,
  required String hint,
}) async {
  final controller = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 300,
        maxLines: 3,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.isEmpty) return;
            Navigator.of(dialogContext).pop(value);
          },
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
  controller.dispose();
  return reason;
}

Future<void> _run(
  BuildContext context,
  Future<String?> Function() action, {
  required String success,
}) async {
  final error = await action();
  if (!context.mounted) return;
  showAppSnackBar(
    context,
    error ?? success,
    kind: error == null ? AppSnackBarKind.success : AppSnackBarKind.error,
  );
}
