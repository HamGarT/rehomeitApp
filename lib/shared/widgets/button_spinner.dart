import 'package:flutter/material.dart';

/// Indicador de progreso del tamaño de un icono, para ocupar el lugar del
/// icono o del texto de un botón mientras su acción está en curso.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key, this.color});

  static const double size = 18;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}
