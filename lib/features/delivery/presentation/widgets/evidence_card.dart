import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/domain/publication.dart';
import '../../../../shared/widgets/publication_image.dart';
import '../../../explore/presentation/explore_controller.dart';
import '../delivery_controller.dart';

/// Fotografía de evidencia y datos de la entrega al destinatario.
class EvidenceCard extends ConsumerWidget {
  const EvidenceCard({
    super.key,
    required this.evidence,
    required this.deliveredById,
  });

  final DeliveryEvidence evidence;
  final String deliveredById;

  static const _photoAspect = 4 / 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appColors;
    final photo = ref.watch(deliveryEvidenceUrlProvider(evidence.storagePath));
    final deliverer = ref.watch(publicProfileProvider(deliveredById));

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: _photoAspect,
            child: photo.when(
              loading: () => ColoredBox(
                color: palette.chipFill,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, _) => ColoredBox(
                color: palette.chipFill,
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: palette.textSecondary,
                  ),
                ),
              ),
              data: (url) => PublicationImage(url: url),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Fact(
                  icon: Icons.schedule,
                  text: formatDateTime(evidence.recordedAt),
                ),
                _Fact(
                  icon: Icons.person_outline,
                  text: 'Destinatario ${evidence.recipientInitials}',
                ),
                _Fact(
                  icon: Icons.location_on_outlined,
                  text: evidence.district,
                ),
                _Fact(
                  icon: Icons.volunteer_activism_outlined,
                  text: 'Entregó ${deliverer.value?.shortName ?? 'un usuario'}',
                ),
                const SizedBox(height: 6),
                Text(
                  'Del destinatario solo se conservan sus iniciales y su distrito.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: palette.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.appColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
