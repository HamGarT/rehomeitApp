import 'package:flutter/material.dart';

/// Poses de la mascota. La oficial es el hámster (D13); saludo y caja son
/// todavía los recortes del cuy anterior, a la espera de su reemplazo.
enum MascotPose {
  wave('assets/images/mascot_wave.webp'),
  box('assets/images/mascot_box.webp'),

  /// GIF en lugar de imagen fija: el hámster dormido funciona mejor dormido, y
  /// el movimiento hace de aviso de que la pantalla está viva sin pedir
  /// interacción.
  sleeping('assets/images/hamster_ligero_durmiendo.gif');

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
