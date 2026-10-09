import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../shared/domain/publication.dart';
import '../../../../shared/widgets/publication_image.dart';
import '../../../explore/presentation/publication_detail_page.dart';
import '../../../../shared/widgets/publication_status_badge.dart';

/// Fila de publicación en la lista del perfil: miniatura, título, distrito y
/// el estado del bien.
///
/// La comparten el perfil propio y el público porque ambos listan publicaciones
/// con su estado y dan acceso al detalle y a su recorrido (HU20, criterios 4 y
/// 17). Lo que cambia entre ambos no es la forma de la fila sino el subtítulo y
/// qué estados llegan a verse.
class ProfilePublicationTile extends StatelessWidget {
  const ProfilePublicationTile({
    super.key,
    required this.publication,
    required this.status,
    this.isOwn = false,
  });

  final Publication publication;

  /// Estado ya resuelto con [Publication.effectiveStatus], no el guardado: en
  /// el perfil importa que una entrega esperando confirmación se lea como tal.
  final PublicationStatus status;

  /// Marca la fila como del dueño de la sesión. Solo el perfil propio lo activa.
  final bool isOwn;

  static const double _thumb = 64;

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicationDetailPage(initial: publication),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;

    return Semantics(
      button: true,
      // `excludeSemantics` para que el lector de pantalla lea una sola frase en
      // lugar de título, distrito y estado por separado.
      label:
          '${publication.title}. ${status.label}. '
          '${isOwn ? 'Tu publicación' : publication.district}',
      excludeSemantics: true,
      container: true,
      child: GestureDetector(
        onTap: () => _open(context),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox.square(
                  dimension: _thumb,
                  child: PublicationImage(
                    url: publication.images.isEmpty
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
                      publication.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOwn ? publication.district : publication.mode.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: palette.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    PublicationStatusBadge(status: status),
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
