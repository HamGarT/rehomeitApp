import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/widgets/publication_image.dart';

/// Mazo de fotos: la de encima muestra la actual y la de atrás asoma por
/// debajo a la derecha. Al tocarla la de atrás pasa al frente con un
/// deslizamiento, así también se ven las que quedan tapadas.
class StackedCards extends StatefulWidget {
  const StackedCards({super.key, required this.images});

  final List<String> images;

  @override
  State<StackedCards> createState() => _StackedCardsState();
}

class _StackedCardsState extends State<StackedCards>
    with SingleTickerProviderStateMixin {
  /// Proporción de la foto, más alta que ancha, para que las imágenes se vean
  /// enteras y no recortadas por los lados.
  static const double _aspect = 1.2;

  /// Margen extra a cada lado, además del padding de la columna: la foto nunca
  /// toca los bordes de la pantalla.
  static const double _sideMargin = 24;

  /// Tope de altura para que en tablets no se vuelva un bloque gigante que
  /// empuja el resto del post fuera de la vista.
  static const double _maxHeight = 440;

  /// Holgura vertical para que la sombra y la rotación no se corten.
  static const double _verticalSlack = 16;

  static const _slideDuration = Duration(milliseconds: 550);

  /// Inclinación de la tarjeta del frente y de la de atrás, en radianes. La
  /// del frente va apenas a la izquierda y la de atrás asoma a la derecha.
  static const double _frontAngle = -0.06;
  static const double _backAngle = 0.12;

  /// Inclinación extra que toma la tarjeta saliente a mitad de recorrido.
  static const double _swingAngle = 0.10;

  static const double _backScale = 0.95;

  /// Cuánto se desplaza la saliente hacia la izquierda, en anchos de tarjeta.
  static const double _slideDistance = 0.65;

  /// Punto del recorrido en que las tarjetas se cruzan y la saliente empieza
  /// a desvanecerse, respectivamente.
  static const double _crossover = 0.5;
  static const double _fadeStart = 0.75;

  /// Sombra de la tarjeta del fondo respecto de la del frente.
  static const double _backElevation = 0.6;

  late final AnimationController _slide;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // En reposo vale 0: así la tarjeta de atrás solo se ve asomando, y con
    // una sola foto no se ve nada.
    _slide = AnimationController(vsync: this, duration: _slideDuration);
    _slide.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      setState(() => _index = (_index + 1) % widget.images.length);
      _slide.value = 0;
    });
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  void _advance() {
    if (_slide.isAnimating) return;
    _slide.forward();
  }

  double _lerp(double a, double b, double p) => a + (b - a) * p;

  Widget _card({
    required String url,
    required double width,
    required double height,
    required double angle,
    required double scale,
    required Offset offset,
    required double opacity,
    required bool dimmed,
    required double elevation,
  }) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: offset,
        child: Transform.rotate(
          angle: angle,
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: width,
              height: height,
              child: _CardFrame(
                dimmed: dimmed,
                elevation: elevation,
                child: PublicationImage(url: url),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Las tres tarjetas del mazo en el instante [p] del deslizamiento, con la
  /// inclinación escalada por [t], que es la entrada inicial del mazo.
  List<Widget> _deck({
    required double width,
    required double height,
    required double p,
    required double t,
  }) {
    final images = widget.images;
    final count = images.length;
    final canCycle = count > 1;
    final current = count == 0 ? null : images[_index];
    final behind = canCycle ? images[(_index + 1) % count] : null;
    final afterNext = canCycle ? images[(_index + 2) % count] : null;
    final swing = math.sin(math.pi * p);

    final outgoing = current == null
        ? null
        : _card(
            url: current,
            width: width,
            height: height,
            angle:
                (_lerp(_frontAngle, _backAngle, p) - _swingAngle * swing) * t,
            scale: _lerp(1.0, _backScale, p),
            offset: Offset(-width * _slideDistance * swing, 0),
            // Al llegar al fondo se desvanece y deja ver la que realmente
            // queda asomando.
            opacity: p < _fadeStart
                ? 1
                : 1 - (p - _fadeStart) / (1 - _fadeStart),
            dimmed: p > _crossover,
            elevation: _lerp(1.0, _backElevation, p),
          );
    final incoming = behind == null
        ? null
        : _card(
            url: behind,
            width: width,
            height: height,
            angle: _lerp(_backAngle, _frontAngle, p) * t,
            scale: _lerp(_backScale, 1.0, p),
            offset: Offset.zero,
            opacity: 1,
            dimmed: p < _crossover,
            elevation: _lerp(_backElevation, 1.0, p),
          );
    final hidden = afterNext == null
        ? null
        : _card(
            url: afterNext,
            width: width,
            height: height,
            angle: _backAngle * t,
            scale: _backScale,
            offset: Offset.zero,
            opacity: 1,
            dimmed: true,
            elevation: _backElevation,
          );

    return [
      ?hidden,
      // El orden de pintado se invierte a mitad del recorrido, cuando la que
      // entra ya pasó por delante de la que sale.
      if (p < _crossover) ...[
        ?incoming,
        ?outgoing,
      ] else ...[
        ?outgoing,
        ?incoming,
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.images.length;
    final canCycle = count > 1;

    // El `LayoutBuilder` va por fuera porque la altura sale del ancho: en una
    // columna sin alto acotado no se puede fijar un alto y a la vez dejar que
    // la tarjeta crezca con la pantalla.
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth - _sideMargin;
        final cardHeight = math.min(cardWidth * _aspect, _maxHeight);

        // Las tarjetas se dibujan a `cardWidth`, más angostas que el espacio
        // disponible; sin `Center` quedan pegadas al borde izquierdo.
        return Center(
          child: SizedBox(
            width: cardWidth,
            height: cardHeight + _verticalSlack,
            child: GestureDetector(
              key: const Key('stacked-cards'),
              onTap: canCycle ? _advance : null,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: _slideDuration,
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => AnimatedBuilder(
                  animation: _slide,
                  builder: (context, _) => Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      ..._deck(
                        width: cardWidth,
                        height: cardHeight,
                        p: Curves.easeInOutCubic.transform(_slide.value),
                        t: t,
                      ),
                      if (canCycle)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 10,
                          child: _PhotoDots(
                            key: const Key('photo-dots'),
                            count: count,
                            active: _index,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Indicador de posición: solo aparece cuando hay más de una foto, porque si
/// no, no hay nada que avanzar.
class _PhotoDots extends StatelessWidget {
  const _PhotoDots({super.key, required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Foto ${active + 1} de $count',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (index) {
          final isActive = index == active;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isActive ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              // Van sobre la foto, así que son blancos en los dos modos.
              color: isActive ? Colors.white : Colors.white54,
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }
}

class _CardFrame extends StatelessWidget {
  const _CardFrame({
    required this.child,
    this.dimmed = false,
    this.elevation = 1.0,
  });

  final Widget child;
  final bool dimmed;
  final double elevation;

  static const double _radius = 20;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(_radius);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18 * elevation),
            blurRadius: 16 * elevation,
            offset: Offset(0, 6 * elevation),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (dimmed) Container(color: Colors.black.withValues(alpha: 0.25)),
          ],
        ),
      ),
    );
  }
}
