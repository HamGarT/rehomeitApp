import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../shared/domain/publication.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/publication_image.dart';
import '../../../explore/presentation/explore_controller.dart';
import '../../../journey/presentation/publication_journey_page.dart';

/// Franja horizontal con los últimos bienes ya entregados. El feed solo lista
/// lo disponible, así que sin ella quien llega no ve que la app se usa.
///
/// Mientras carga, si falla o si no hay entregas no ocupa espacio: es un
/// complemento del feed y no debe mostrar estados propios.
class RehomedStrip extends ConsumerWidget {
  const RehomedStrip({super.key});

  static const _cardWidth = 132.0;
  static const _stripHeight = 186.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rehomed = ref.watch(rehomedPublicationsProvider).value ?? const [];
    if (rehomed.isEmpty) return const SizedBox.shrink();

    return Column(
      key: const Key('rehomed-strip'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text(
            'Ya encontraron hogar',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: context.appColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          height: _stripHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: rehomed.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => SizedBox(
              width: _cardWidth,
              child: _RehomedCard(publication: rehomed[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _RehomedCard extends StatelessWidget {
  const _RehomedCard({required this.publication});

  final Publication publication;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDonation = publication.isDonation;
    final outcome = isDonation ? 'Donado' : 'Intercambiado';

    // `GestureDetector` y no `InkWell`: la página vive en el `Scaffold` del
    // shell sin `Material` propio.
    return Semantics(
      button: true,
      label: '${publication.title}, $outcome. Ver recorrido',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => pushUnique(
          context,
          name: AppRoutes.journey(publication.id),
          builder: (_) => PublicationJourneyPage(initial: publication),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PublicationImage(
                      url: publication.images.isEmpty
                          ? null
                          : publication.images.first,
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: AppBadge(
                        label: outcome,
                        background: isDonation
                            ? AppColors.success
                            : AppColors.accent,
                        foreground: AppColors.onAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              publication.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              publication.district,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
