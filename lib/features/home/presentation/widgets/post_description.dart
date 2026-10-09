import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Descripción del post: dos líneas y "...más" al final cuando el texto no
/// cabe. Al tocarla se despliega entera y muestra "...menos" para plegarla.
///
/// El recorte se calcula con un [TextPainter] en lugar del `ellipsis` de
/// [Text], porque el `ellipsis` se comería el propio "...más": iría al final
/// de la última línea visible, que es justo donde no queda sitio.
class PostDescription extends StatefulWidget {
  const PostDescription({super.key, required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<PostDescription> createState() => _PostDescriptionState();
}

class _PostDescriptionState extends State<PostDescription> {
  static const int _maxLines = 2;
  static const String _more = '...más';
  static const String _less = '...menos';

  bool _expanded = false;

  @override
  void didUpdateWidget(covariant PostDescription oldWidget) {
    // El feed se reordena y recicla tarjetas: si la publicación cambió, el
    // plegado que había ya no corresponde a este texto.
    if (oldWidget.text != widget.text) _expanded = false;
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    if (text.isEmpty) return const SizedBox.shrink();

    // `LayoutBuilder` dentro del `Padding`: el ancho se mide sobre el espacio
    // que de verdad ocupa el texto. Medido por fuera sobran los 40 px de
    // margen y las descripciones que llenan dos líneas se recortan sin aviso.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final folded = _fold(constraints.maxWidth);
          final isTruncated = folded != text;
          // Solo hay algo que desplegar si de verdad se recortó: si el texto
          // entra entero, tocarlo no hace nada y no aparece ningún sufijo.
          final expanded = _expanded && isTruncated;
          final suffix = expanded ? _less : (isTruncated ? _more : '');
          final content = expanded ? text : folded;

          return GestureDetector(
            onTap: isTruncated
                ? () => setState(() => _expanded = !_expanded)
                : null,
            child: RichText(
              key: const Key('post-description'),
              maxLines: expanded ? null : _maxLines,
              text: TextSpan(
                style: widget.style,
                children: [
                  TextSpan(text: content),
                  if (suffix.isNotEmpty) TextSpan(text: ' $suffix'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Devuelve el texto tal cual si cabe en [_maxLines] líneas; si no, el texto
  /// recortado en un límite de palabra. El sufijo lo pone quien llama, para
  /// que pueda ser "...más" o "...menos" según el estado.
  String _fold(double width) {
    final text = widget.text;
    final style = widget.style;
    final direction = Directionality.of(context);

    // El ancho de "...más" se descuenta antes de componer el cuerpo: si no,
    // el texto llenaría las dos líneas enteras y el sufijo se saldría.
    final suffixWidth = (TextPainter(
      text: TextSpan(text: _more, style: style),
      textDirection: direction,
    )..layout()).width;
    final bodyWidth = math.max(0.0, width - suffixWidth);

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      maxLines: _maxLines,
      ellipsis: '',
    )..layout(maxWidth: bodyWidth);
    if (!painter.didExceedMaxLines) return text;

    final lines = painter.computeLineMetrics();
    if (lines.isEmpty) return text;

    // Cursor al final de la última línea compuesta, y de ahí el comienzo de
    // la palabra que quedó partida.
    final end = painter.getPositionForOffset(
      Offset(painter.width, lines.last.baseline),
    );
    final wordStart = painter.getWordBoundary(end).start;
    // Una sola palabra más larga que la línea no tiene límite previo: se
    // corta justo donde el motor dejó de dibujar.
    final cut = wordStart > 0 ? wordStart : end.offset;
    if (cut <= 0 || cut >= text.length) return text;

    return text.substring(0, cut).trimRight();
  }
}
