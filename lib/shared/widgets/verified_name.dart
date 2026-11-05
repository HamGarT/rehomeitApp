import 'package:flutter/material.dart';

/// Nombre con insignia azul para una cuenta verificada.
class VerifiedName extends StatelessWidget {
  const VerifiedName({
    super.key,
    required this.name,
    required this.isVerified,
    this.style,
    this.maxLines = 1,
  });

  final String name;
  final bool isVerified;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (isVerified) ...[
          const SizedBox(width: 4),
          const Icon(
            Icons.verified,
            color: Color(0xFF1D9BF0),
            size: 17,
            semanticLabel: 'Cuenta verificada',
          ),
        ],
      ],
    );
  }
}
