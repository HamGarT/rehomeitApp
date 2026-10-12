import 'package:flutter/material.dart';

/// Avatar de una persona: su foto si la tiene, y si no, la inicial del nombre.
/// Lo comparten la cabecera del perfil, el feed y el detalle (D10), así la
/// foto de HU20-9 aparece en todos los sitios donde hoy va la inicial.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    required this.radius,
    this.photoUrl,
    this.backgroundColor,
    this.foregroundColor,
    this.textStyle,
  });

  final String name;
  final double radius;
  final String? photoUrl;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        foregroundImage: NetworkImage(url),
        // Mientras carga, o si falla, se ve la inicial y no un hueco.
        child: _Initial(name: name, color: foregroundColor, style: textStyle),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: _Initial(name: name, color: foregroundColor, style: textStyle),
    );
  }
}

/// Con el nombre vacío cae en "U": mejor una letra genérica que el icono de
/// persona, que parece un error.
String avatarInitial(String? name) {
  final trimmed = name?.trim() ?? '';
  return trimmed.isEmpty ? 'U' : trimmed[0].toUpperCase();
}

class _Initial extends StatelessWidget {
  const _Initial({required this.name, this.color, this.style});

  final String name;
  final Color? color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(avatarInitial(name), style: (style ?? const TextStyle()).copyWith(color: color));
  }
}
