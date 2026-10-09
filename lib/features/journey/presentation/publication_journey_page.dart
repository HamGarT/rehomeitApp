import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/domain/publication.dart';
import '../../../shared/widgets/publication_mode_badge.dart';
import '../../../shared/widgets/publication_status_badge.dart';
import '../../delivery/presentation/widgets/evidence_card.dart';
import '../../exchange/presentation/exchange_controller.dart';
import '../../explore/presentation/explore_controller.dart';
import 'journey_controller.dart';

/// Recorrido del bien (HU14): hitos alcanzados y pendientes, quién generó
/// cada uno, la evidencia de entrega y el estado actual.
class PublicationJourneyPage extends ConsumerWidget {
  const PublicationJourneyPage({super.key, required this.initial});

  final Publication initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(publicationJourneyProvider(initial.id));
    final publication = snapshot.value?.publication ?? initial;
    final isFromCache = snapshot.value?.isFromCache ?? false;
    final now = ref.watch(exchangeClockProvider).value ?? DateTime.now();
    final status = publication.effectiveStatus(now);
    final reached = publication.milestones(now);
    final reachedStatuses = reached.map((m) => m.status).toSet();
    final isTerminal = const {
      PublicationStatus.confirmed,
      PublicationStatus.closedWithoutConfirmation,
      PublicationStatus.cancelled,
      PublicationStatus.removed,
    }.contains(status);
    final pending = isTerminal
        ? const <PublicationStatus>[]
        : publication.expectedPath
              .where((step) => !reachedStatuses.contains(step))
              .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recorrido del bien'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartir comprobante',
            onPressed: () => _share(publication, reached, status),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (isFromCache)
            const _Notice(
              icon: Icons.cloud_off_outlined,
              text: 'Sin conexión. El recorrido puede no estar actualizado.',
            ),
          Text(
            publication.title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PublicationModeBadge(mode: publication.mode),
              PublicationStatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 16),
          if (status == PublicationStatus.confirmed)
            const _Notice(
              icon: Icons.verified_outlined,
              text: 'Ciclo completo y verificable.',
              positive: true,
            ),
          if (status == PublicationStatus.closedWithoutConfirmation)
            const _Notice(
              icon: Icons.warning_amber_outlined,
              text: 'La operación se cerró sin la confirmación del donante.',
            ),
          if (status == PublicationStatus.cancelled ||
              status == PublicationStatus.removed)
            _Notice(
              icon: Icons.remove_circle_outline,
              text: 'La publicación fue ${status.label.toLowerCase()}.',
            ),
          for (var index = 0; index < reached.length; index++)
            _MilestoneTile(
              publication: publication,
              status: reached[index].status,
              at: reached[index].at,
              isLast: pending.isEmpty && index == reached.length - 1,
            ),
          for (var index = 0; index < pending.length; index++)
            _MilestoneTile(
              publication: publication,
              status: pending[index],
              isLast: index == pending.length - 1,
            ),
          if (publication.isDonation && publication.deliveryEvidence == null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Del destinatario solo se conservarán sus iniciales y su distrito.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: context.appColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _share(
    Publication publication,
    List<PublicationMilestone> reached,
    PublicationStatus status,
  ) {
    final lines = [
      'Recorrido de "${publication.title}" (${publication.mode.label})',
      'Estado: ${status.label}',
      '',
      for (final milestone in reached)
        '${formatDateTime(milestone.at)}  '
            '${milestoneTitle(publication, milestone.status)}',
      '',
      'Comprobante generado desde ReHomeIt.',
    ];
    return SharePlus.instance.share(
      ShareParams(
        text: lines.join('\n'),
        subject: 'Recorrido de ${publication.title}',
      ),
    );
  }
}

/// Nombre del hito según la ruta del bien (HU14-2 y HU14-8).
String milestoneTitle(Publication publication, PublicationStatus status) {
  if (!publication.isDonation) {
    return switch (status) {
      PublicationStatus.published => 'Publicación',
      PublicationStatus.committed => 'Propuesta aceptada',
      PublicationStatus.delivered => 'Primera confirmación',
      PublicationStatus.confirmed => 'Intercambio concretado',
      _ => status.label,
    };
  }
  if (publication.deliveryType == DeliveryType.owner) {
    return switch (status) {
      PublicationStatus.published => 'Publicación',
      PublicationStatus.confirmed => 'Entrega registrada por el donante',
      _ => status.label,
    };
  }
  return switch (status) {
    PublicationStatus.published => 'Publicación',
    PublicationStatus.committed => 'Compromiso del voluntario',
    PublicationStatus.pickedUp => 'Recojo confirmado por el donante',
    PublicationStatus.delivered => 'Entrega registrada',
    PublicationStatus.confirmed => 'Cierre confirmado',
    _ => status.label,
  };
}

class _MilestoneTile extends ConsumerWidget {
  const _MilestoneTile({
    required this.publication,
    required this.status,
    required this.isLast,
    this.at,
  });

  final Publication publication;
  final PublicationStatus status;
  final DateTime? at;
  final bool isLast;

  bool get _reached => at != null;

  static const double _iconSize = 22;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appColors;
    final actorId = _reached ? publication.milestoneActorId(status) : null;
    final actor = actorId == null
        ? null
        : ref.watch(publicProfileProvider(actorId)).value?.shortName;
    final evidence = publication.deliveryEvidence;
    final showsEvidence =
        _reached &&
        evidence != null &&
        status ==
            (publication.deliveryType == DeliveryType.owner
                ? PublicationStatus.confirmed
                : PublicationStatus.delivered);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Icon(
                _reached ? Icons.check_circle : Icons.radio_button_unchecked,
                size: _iconSize,
                color: _reached ? palette.primary : palette.border,
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: palette.border)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    milestoneTitle(publication, status),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _reached
                          ? palette.textPrimary
                          : palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _reached
                        ? [
                            formatDateTime(at!),
                            if (actor != null && actor.isNotEmpty) 'por $actor',
                          ].join('  ·  ')
                        : 'Pendiente',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: palette.textSecondary),
                  ),
                  if (showsEvidence) ...[
                    const SizedBox(height: 10),
                    EvidenceCard(
                      evidence: evidence,
                      deliveredById:
                          publication.volunteerId ?? publication.authorId,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.text,
    this.positive = false,
  });

  final IconData icon;
  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;
    final color = positive ? AppColors.success : palette.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
