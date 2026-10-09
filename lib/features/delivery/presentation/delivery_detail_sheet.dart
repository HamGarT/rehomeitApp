import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/domain/publication.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/button_spinner.dart';
import '../../../shared/widgets/sheet_handle.dart';
import 'delivery_controller.dart';
import 'widgets/evidence_card.dart';

/// Detalle de la entrega registrada (HU13). Devuelve `true` si el donante
/// confirmó el cierre desde aquí.
Future<bool> showDeliveryDetailSheet(
  BuildContext context, {
  required Publication publication,
  required String userId,
}) async {
  final closed = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) =>
        _DeliveryDetailSheet(publication: publication, userId: userId),
  );
  return closed ?? false;
}

class _DeliveryDetailSheet extends ConsumerWidget {
  const _DeliveryDetailSheet({required this.publication, required this.userId});

  final Publication publication;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evidence = publication.deliveryEvidence;
    final busy = ref.watch(deliveryControllerProvider).isLoading;
    final canConfirm = publication.canConfirmClose(userId, DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 16),
            Text(
              'Entrega registrada',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            if (evidence != null)
              EvidenceCard(
                evidence: evidence,
                deliveredById: publication.volunteerId ?? publication.authorId,
              )
            else
              const Text('La entrega no tiene evidencia registrada.'),
            if (canConfirm) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: busy ? null : () => _confirmClose(context, ref),
                icon: busy
                    ? const ButtonSpinner()
                    : const Icon(Icons.verified_outlined),
                label: const Text('Confirmar cierre'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClose(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirmDialog(
      context,
      icon: Icons.verified_outlined,
      title: '¿Confirmar el cierre?',
      subtitle:
          'Confirma solo si la evidencia corresponde a tu donación. '
          'La operación quedará cerrada.',
      confirmLabel: 'Confirmar cierre',
    );
    if (!confirmed || !context.mounted) return;
    final error = await ref
        .read(deliveryControllerProvider.notifier)
        .confirmClose(publication, userId);
    if (!context.mounted) return;
    if (error != null) {
      showAppSnackBar(context, error, kind: AppSnackBarKind.error);
      return;
    }
    Navigator.of(context).pop(true);
  }
}
