import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/user_avatar.dart';

/// Cabecera de perfil: quién es la persona, de dónde es y desde cuándo está.
///
/// Va sobre el amarillo de marca, como el cta de publicar del inicio. Es la
/// única superficie de la pantalla con ese fondo porque es la que identifica a
/// la persona, y repetirlo más abajo competiría con el contenido.
///
/// El perfil propio muestra el nombre completo y el correo; el público solo el
/// nombre abreviado (HU20, criterios 2, 13 y 16). Lo que se decide con [isOwn]
/// no son detalles de maquetación: el correo nunca se escribe en una pantalla
/// ajena, ni aunque el documento llegue con él.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.name,
    required this.district,
    required this.joinedAt,
    required this.isOwn,
    this.email,
    this.photoUrl,
    this.onEdit,
  });

  final String name;
  final String district;

  /// Puede venir nulo si `perfiles/{uid}` todavía no existe; entonces la fecha
  /// se omite en lugar de inventar una.
  final DateTime? joinedAt;

  final bool isOwn;

  /// Solo se pinta en el perfil propio. El perfil público no lo recibe.
  final String? email;

  final String? photoUrl;

  /// Abre la edición del perfil (HU20-9). Solo el perfil propio lo pasa.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(28),
      ),
      // Recorta al hijo para que el avatar no se salga del radio de la tarjeta.
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              UserAvatar(
                name: name,
                radius: 32,
                photoUrl: photoUrl,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                textStyle: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: texts.titleLarge?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
              if (onEdit != null)
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'Editar perfil',
                  color: Colors.black,
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // Sobre amarillo el texto va siempre oscuro, en los dos modos: el
          // relleno es el mismo en ambos.
          if (district.isNotEmpty)
            _HeaderFact(icon: Icons.location_on_outlined, text: district),
          if (joinedAt != null)
            _HeaderFact(
              icon: Icons.calendar_today_outlined,
              text: joinedSince(joinedAt!),
            ),
          if (isOwn && email != null && email!.isNotEmpty)
            _HeaderFact(icon: Icons.mail_outline, text: email!),
        ],
      ),
    );
  }
}

/// Inicial del avatar; la misma regla que el resto de avatares.
String initial(String name) => avatarInitial(name);

const _months = <String>[
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// "Se unió en marzo de 2026".
///
/// Los nombres de mes van a mano porque la aplicación no trae `intl`: es la
/// única fecha con nombre que se muestra, y una tabla de doce cadenas cuesta
/// menos que el paquete.
String joinedSince(DateTime joinedAt) {
  final local = joinedAt.toLocal();
  final month = _months[local.month - 1];
  return 'Se unió en $month de ${local.year}';
}

class _HeaderFact extends StatelessWidget {
  const _HeaderFact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black87),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
