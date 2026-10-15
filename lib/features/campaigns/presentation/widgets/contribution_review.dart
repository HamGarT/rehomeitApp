import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../domain/contribution.dart';
import '../contribution_controller.dart';
import 'reject_contribution_dialog.dart';

/// Confirma un aporte recibido y muestra el resultado. La usan el detalle de la
/// campaña y el perfil de la organización.
Future<void> confirmContribution(
  BuildContext context,
  WidgetRef ref,
  Contribution contribution,
  String organizationId,
) async {
  final confirmed = await showAppConfirmDialog(
    context,
    title: '¿Confirmar este aporte?',
    subtitle: 'Se sumará al avance de la campaña.',
    confirmLabel: 'Confirmar',
  );
  if (!confirmed || !context.mounted) return;
  final error = await ref
      .read(contributionControllerProvider.notifier)
      .confirm(contribution: contribution, organizationId: organizationId);
  if (!context.mounted) return;
  showAppSnackBar(
    context,
    error ?? 'Aporte confirmado.',
    kind: error == null ? AppSnackBarKind.success : AppSnackBarKind.error,
  );
}

/// Rechaza un aporte pidiendo el motivo y muestra el resultado.
Future<void> rejectContribution(
  BuildContext context,
  WidgetRef ref,
  Contribution contribution,
  String organizationId,
) async {
  final reason = await showRejectContributionDialog(context);
  if (reason == null || !context.mounted) return;
  final error = await ref
      .read(contributionControllerProvider.notifier)
      .reject(
        contribution: contribution,
        organizationId: organizationId,
        reason: reason,
      );
  if (!context.mounted) return;
  showAppSnackBar(
    context,
    error ?? 'Aporte rechazado.',
    kind: error == null ? AppSnackBarKind.success : AppSnackBarKind.error,
  );
}
