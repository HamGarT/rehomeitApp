import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/constants/app_colors.dart';
import '../domain/publication.dart';
import 'app_badge.dart';

/// Distintivo con el estado de una publicación en la lista del perfil.
///
/// El color dice en qué punto está el ciclo sin tener que leer la etiqueta:
/// verde cuando la operación se cerró confirmada, ámbar cuando hay una entrega
/// esperando confirmación, rojo cuando se retiró, y un neutro de paleta para
/// todo lo demás.
///
/// El amarillo de marca no se usa como estado: está reservado a las superficies
/// de marca y si todo resaltara, nada resaltaría (D13).
class PublicationStatusBadge extends StatelessWidget {
  const PublicationStatusBadge({super.key, required this.status});

  final PublicationStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;

    final (background, foreground) = switch (status) {
      PublicationStatus.confirmed => (AppColors.success, AppColors.onAccent),
      PublicationStatus.pendingConfirmation => (
        AppColors.warning,
        Colors.white,
      ),
      PublicationStatus.removed => (AppColors.error, Colors.white),
      // Neutros: fondo y texto salen de la paleta para que el distintivo se
      // lea igual en claro y en oscuro, donde los grises están invertidos.
      _ => (palette.chipFill, palette.textSecondary),
    };

    return AppBadge(
      label: status.label,
      background: background,
      foreground: foreground,
    );
  }
}
