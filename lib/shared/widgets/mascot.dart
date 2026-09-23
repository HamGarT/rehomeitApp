import 'package:flutter/material.dart';

/// Poses disponibles del cuy, recortadas de las ilustraciones del onboarding.
enum MascotPose {
  wave('assets/images/mascot_wave.webp'),
  box('assets/images/mascot_box.webp');

  const MascotPose(this.asset);

  final String asset;
}

/// La mascota aparece solo en momentos con carga emocional: esperar, no
/// encontrar nada, publicar con éxito o despedirse. No decora todo.
class Mascot extends StatelessWidget {
  const Mascot({super.key, this.pose = MascotPose.wave, this.height = 160});

  final MascotPose pose;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      pose.asset,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
  }
}
