import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

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
  });

  final String name;
  final String district;

  /// Puede venir nulo si `perfiles/{uid}` todavía no existe; entonces la fecha
  /// se omite en lugar de inventar una.
  final DateTime? joinedAt;

  final bool isOwn;

  /// Solo se pinta en el perfil propio. El perfil público no lo recibe.
  final String? email;

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
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial(name),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
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

/// Inicial del avatar. Con el nombre vacío cae en "U", igual que en el inicio:
/// mejor una letra genérica que el ícono de persona, que parece un error.
String initial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'U';
  return trimmed[0].toUpperCase();
}

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
