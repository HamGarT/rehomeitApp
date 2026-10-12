import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/mascot.dart';
import '../../../shared/widgets/publication_image.dart';
import '../../explore/presentation/explore_controller.dart';
import '../domain/publication_report.dart';
import 'moderation_controller.dart';
import 'report_review_sheet.dart';

/// Consola de moderación: los reportes pendientes, del más antiguo al más
/// nuevo (HU19-8). Solo llega aquí una cuenta con rol de administrador.
class ModerationPage extends ConsumerWidget {
  const ModerationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(pendingReportsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes pendientes')),
      body: reports.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _ModerationError(
          onRetry: () => ref.invalidate(pendingReportsProvider),
        ),
        data: (items) => items.isEmpty
            ? const _NoReports()
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _ReportTile(report: items[index]),
              ),
      ),
    );
  }
}

class _ReportTile extends ConsumerWidget {
  const _ReportTile({required this.report});

  final PublicationReport report;

  static const double _thumb = 64;

  Future<void> _open(BuildContext context) async {
    final outcome = await showReportReviewSheet(context, report: report);
    if (outcome == null || !context.mounted) return;
    showAppSnackBar(context, outcome, kind: AppSnackBarKind.success);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appColors;
    final publication = ref
        .watch(publicationDetailProvider(report.publicationId))
        .value;
    final reporter = ref.watch(publicProfileProvider(report.reporterId)).value;
    final comment = report.comment;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox.square(
                  dimension: _thumb,
                  child: PublicationImage(
                    url: publication == null || publication.images.isEmpty
                        ? null
                        : publication.images.first,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      publication?.title ?? 'Publicación no disponible',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    ReportReasonBadge(reason: report.reason),
                    const SizedBox(height: 6),
                    Text(
                      'Reportado por ${reporter?.shortName ?? 'un usuario'} · '
                      '${timeAgo(report.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: palette.textSecondary),
                    ),
                    if (comment != null && comment.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        comment,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 22, color: palette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Motivo del reporte como distintivo. Ámbar en toda la consola: es un aviso
/// por revisar, no un error ni un éxito.
class ReportReasonBadge extends StatelessWidget {
  const ReportReasonBadge({super.key, required this.reason});

  final ReportReason reason;

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      label: reason.label,
      background: AppColors.warning.withValues(alpha: 0.18),
      foreground: AppColors.warning,
    );
  }
}

class _NoReports extends StatelessWidget {
  const _NoReports();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Mascot(pose: MascotPose.sleeping, height: 170),
            const SizedBox(height: 16),
            Text(
              'Nada por revisar',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontFamily: 'FreckleFace',
                fontSize: 24,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando alguien reporte una publicación aparecerá aquí.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: context.appColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModerationError extends StatelessWidget {
  const _ModerationError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('No se pudo cargar los reportes.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
