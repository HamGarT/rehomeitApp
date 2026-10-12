import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/domain/publication.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/button_spinner.dart';
import '../../../shared/widgets/publication_image.dart';
import '../../../shared/widgets/publication_mode_badge.dart';
import '../../../shared/widgets/publication_status_badge.dart';
import '../../../shared/widgets/sheet_handle.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../explore/presentation/explore_controller.dart';
import '../../explore/presentation/publication_detail_page.dart';
import '../domain/publication_report.dart';
import 'moderation_controller.dart';
import 'moderation_page.dart';

/// Hoja de revisión de un reporte (HU19-9 a 11). Devuelve el mensaje de
/// resultado si el administrador resolvió, o `null` si cerró sin resolver; la
/// confirmación la muestra la consola, para que no quede tapada por la hoja.
Future<String?> showReportReviewSheet(
  BuildContext context, {
  required PublicationReport report,
}) {
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => _ReportReviewSheet(report: report),
  );
}

class _ReportReviewSheet extends ConsumerStatefulWidget {
  const _ReportReviewSheet({required this.report});

  final PublicationReport report;

  @override
  ConsumerState<_ReportReviewSheet> createState() => _ReportReviewSheetState();
}

class _ReportReviewSheetState extends ConsumerState<_ReportReviewSheet> {
  String? _error;

  PublicationReport get report => widget.report;

  @override
  Widget build(BuildContext context) {
    final publication = ref
        .watch(publicationDetailProvider(report.publicationId))
        .value;
    final reporter = ref.watch(publicProfileProvider(report.reporterId)).value;
    final adminId = ref.watch(
      authStateProvider.select((auth) => auth.value?.uid),
    );
    final busy = ref.watch(moderationControllerProvider).isLoading;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Text(
                'Revisar reporte',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: publication == null
                  ? const _PublicationMissing()
                  : _PublicationSummary(publication: publication),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _ReportDetails(report: report, reporterName: reporter?.shortName),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: _actions(publication, adminId, busy),
            ),
          ],
        ),
      ),
    );
  }

  /// Qué se puede hacer depende del estado del bien: retirar solo mientras
  /// no cambió de manos; si ya está retirada, cerrar el reporte; en el resto
  /// de casos solo desestimar, con la razón a la vista.
  Widget _actions(Publication? publication, String? adminId, bool busy) {
    // Sin sesión no hay nada que resolver; la hoja no se abre en ese estado.
    if (publication == null || adminId == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final disabled = busy;
    final dismissButton = OutlinedButton.icon(
      key: const Key('review-dismiss'),
      onPressed: disabled ? null : () => _dismiss(publication, adminId),
      icon: const Icon(Icons.check),
      label: const Text('Desestimar reporte'),
    );

    if (publication.isRemovableByModeration) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            key: const Key('review-remove'),
            onPressed: disabled ? null : () => _remove(publication, adminId),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            icon: busy
                ? const ButtonSpinner()
                : const Icon(Icons.remove_circle_outline),
            label: const Text('Retirar publicación'),
          ),
          const SizedBox(height: 10),
          dismissButton,
        ],
      );
    }

    if (publication.status == PublicationStatus.removed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StateNotice(
            icon: Icons.remove_circle_outline,
            text: 'La publicación ya fue retirada. Solo falta cerrar este reporte.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('review-close'),
            onPressed: disabled
                ? null
                : () => _resolveAlreadyRemoved(publication, adminId),
            icon: busy ? const ButtonSpinner() : const Icon(Icons.done_all),
            label: const Text('Marcar como resuelto'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StateNotice(
          icon: Icons.info_outline,
          text: publication.status == PublicationStatus.cancelled
              ? 'El autor ya anuló esta publicación; no hay nada que retirar.'
              : 'El bien ya cambió de manos (${publication.status.label.toLowerCase()}). Retirarlo no evitaría nada y dejaría la entrega sin cierre.',
        ),
        const SizedBox(height: 12),
        dismissButton,
      ],
    );
  }

  Future<void> _remove(Publication publication, String adminId) async {
    final confirmed = await showAppConfirmDialog(
      context,
      icon: Icons.remove_circle_outline,
      destructive: true,
      title: '¿Retirar la publicación?',
      subtitle:
          'Saldrá del inicio y del detalle, el autor recibirá el motivo y '
          'cualquier compromiso o propuesta activa quedará cancelada. No se '
          'puede deshacer.',
      confirmLabel: 'Retirar',
    );
    if (!confirmed || !mounted) return;
    final error = await ref
        .read(moderationControllerProvider.notifier)
        .removePublication(
          report: report,
          publication: publication,
          adminId: adminId,
        );
    _finish(error, 'Publicación retirada y reporte resuelto');
  }

  Future<void> _dismiss(Publication publication, String adminId) async {
    final confirmed = await showAppConfirmDialog(
      context,
      icon: Icons.check,
      title: '¿Desestimar el reporte?',
      subtitle:
          'La publicación seguirá disponible y quien reportó recibirá el aviso.',
      confirmLabel: 'Desestimar',
    );
    if (!confirmed || !mounted) return;
    final error = await ref
        .read(moderationControllerProvider.notifier)
        .dismiss(report: report, publication: publication, adminId: adminId);
    _finish(error, 'Reporte desestimado');
  }

  Future<void> _resolveAlreadyRemoved(
    Publication publication,
    String adminId,
  ) async {
    final error = await ref
        .read(moderationControllerProvider.notifier)
        .resolveAlreadyRemoved(
          report: report,
          publication: publication,
          adminId: adminId,
        );
    _finish(error, 'Reporte resuelto');
  }

  void _finish(String? error, String success) {
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(success);
  }
}

class _PublicationSummary extends ConsumerWidget {
  const _PublicationSummary({required this.publication});

  final Publication publication;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appColors;
    final author = ref.watch(publicProfileProvider(publication.authorId)).value;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox.square(
                  dimension: 72,
                  child: PublicationImage(
                    url: publication.images.isEmpty
                        ? null
                        : publication.images.first,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      publication.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'por ${author?.shortName ?? 'usuario'} · ${publication.district}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: palette.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        PublicationModeBadge(mode: publication.mode),
                        PublicationStatusBadge(status: publication.status),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => pushUnique(
                context,
                name: AppRoutes.publication(publication.id),
                builder: (_) => PublicationDetailPage(initial: publication),
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Ver publicación'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicationMissing extends StatelessWidget {
  const _PublicationMissing();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Text(
          'Cargando la publicación...',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: context.appColors.textSecondary),
        ),
      ],
    );
  }
}

class _ReportDetails extends StatelessWidget {
  const _ReportDetails({required this.report, required this.reporterName});

  final PublicationReport report;
  final String? reporterName;

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;
    final comment = report.comment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReportReasonBadge(reason: report.reason),
        const SizedBox(height: 8),
        Text(
          comment == null || comment.isEmpty ? 'Sin comentario.' : comment,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: comment == null || comment.isEmpty
                ? palette.textSecondary
                : palette.textPrimary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Reportado por ${reporterName ?? 'un usuario'} · ${formatDateTime(report.createdAt)}',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: palette.textSecondary),
        ),
      ],
    );
  }
}

class _StateNotice extends StatelessWidget {
  const _StateNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.appColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
