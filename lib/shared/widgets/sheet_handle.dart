import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Asa de las hojas inferiores. El tema desactiva `showDragHandle` porque el
/// asa de Material no sigue la paleta; esta sí, y va centrada aunque la
/// columna que la contiene estire a sus hijos.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: context.appColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
