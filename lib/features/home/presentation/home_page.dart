import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:math' as math;

import '../../../app/theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/domain/publication.dart';
import '../../../shared/widgets/mascot.dart';
import '../../../shared/widgets/publication_image.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../explore/domain/public_profile.dart';
import '../../explore/presentation/explore_controller.dart';
import '../../explore/presentation/explore_page.dart';
import '../../explore/presentation/publication_detail_page.dart';
import '../../moderation/presentation/report_publication_sheet.dart';
import '../../profile/presentation/public_profile_page.dart';
import '../../publishing/presentation/photos_step.dart';
import '../../publishing/presentation/publish_draft_notifier.dart';
import 'post_actions_notifier.dart';

/// Abre el flujo de publicación. El shell también lo hace al pulsar la pestaña
/// "Publicar", así que el estado del borrador se reinicia en los dos casos.
void _startPublishing(WidgetRef ref) {
  ref.read(publishDraftProvider.notifier).reset();
  Navigator.of(ref.context)
      .push(MaterialPageRoute(builder: (_) => const PhotosStep()));
}

/// Normaliza un texto a hashtag: minúsculas, sin tildes ni signos y sin
/// espacios interiores. "Ropa de cama y abrigo" pasa a "ropadecama", porque un
/// hashtag no puede contener espacios y se lee mejor pegado que con guiones.
String _hashtagify(String value) {
  const accents = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const plain = 'aaaaaeeeeiiiiooooouuuunc';
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final index = accents.indexOf(char);
    if (index != -1) {
      buffer.write(plain[index]);
    } else if (RegExp(r'[a-z0-9]').hasMatch(char)) {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

/// Hashtags de la tarjeta: modalidad, categoría, estado del bien y distrito.
/// Los cuatro valores vienen guardados en la publicación, no de una lista
/// aquí, así el feed no puede desincronizarse de lo que la persona publicó.
List<String> _postHashtags(Publication publication) {
  final raw = [
    publication.mode.wireValue,
    publication.category,
    // "Estado del bien": `Nuevo`, `Como nuevo` o `Usado`.
    publication.condition,
    publication.district,
  ];
  final seen = <String>{};
  final tags = <String>[];
  for (final value in raw) {
    final tag = _hashtagify(value);
    // `set.add` devuelve false si ya estaba: así una categoría que se repita
    // no produce "#ropainfantil #ropainfantil".
    if (tag.isEmpty || !seen.add(tag)) continue;
    tags.add(tag);
  }
  return tags;
}

/// Nombre que se ve en la cabecera del post. Mientras el perfil público no
/// llega se cae a [PublicProfile]'s propio texto por defecto en vez de dejar
/// un hueco, y si el documento no existe (o el read falla, porque
/// `auth_repository` se traga los errores al crear los documentos) se muestra
/// el mismo texto genérico. Nunca el identificador: un uid de Firestore en la
/// cabecera es ruido para quien lee el feed.
String _authorName(AsyncValue<PublicProfile?> profile) {
  final shortName = profile.value?.shortName ?? '';
  if (shortName.trim().isEmpty) return 'Usuario de ReHomeIt';
  return shortName;
}

/// Inicial del avatar. Con el mismo texto genérico del nombre, cae en "U" en
/// vez de dejar el ícono de persona.
String _initial(String? shortName) {
  final name = (shortName ?? '').trim();
  if (name.isEmpty) return 'U';
  return name[0].toUpperCase();
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(exploreFeedProvider);
    final userId = ref.watch(authStateProvider).value?.uid;
    void startPublishing() => _startPublishing(ref);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: const Text(
            'Rehomeit',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  // `ExplorePage` no trae `Scaffold`: antes lo sostenía el del
                  // shell. Como ruta propia hay que dárselo aquí, o los sheets
                  // de filtro fallan por falta de un `Material` ancestro.
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Explorar')),
                    body: const ExplorePage(),
                  ),
                ),
              ),
            ),
          ],
        ),
        feed.when(
          data: (data) {
            // El cta dice "todavía no has publicado nada", así que solo tiene
            // sentido mientras la persona no tenga ninguna publicación propia.
            // Se filtra en cliente porque el feed ya viene cargado.
            final hasOwn = data.publications.any((p) => p.authorId == userId);
            if (!hasOwn) {
              return SliverToBoxAdapter(
                child: _PublishCta(onPublish: startPublishing),
              );
            }
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          },
          // Mientras carga no se sabe si tiene publicaciones: se muestra para
          // no hidear el contenido de golpe al llegar los datos.
          loading: () => SliverToBoxAdapter(
            child: _PublishCta(onPublish: startPublishing),
          ),
          error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),
        const SliverToBoxAdapter(child: _SectionHeader()),
        feed.when(
          data: (data) {
            if (data.publications.isEmpty) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }
            return SliverList.builder(
              itemCount: data.publications.length,
              itemBuilder: (context, index) => _FeedPost(
                publication: data.publications[index],
                currentUserId: userId,
              ),
            );
          },
          error: (error, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudo cargar el feed.',
                style: TextStyle(color: context.appColors.textSecondary),
              ),
            ),
          ),
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

/// Cabecera de la tarjeta "publica algo": es el estado vacío del feed, así que
/// solo aparece cuando la persona todavía no tiene publicaciones.
class _PublishCta extends StatelessWidget {
  const _PublishCta({required this.onPublish});

  final VoidCallback onPublish;

  static const _mascotHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hey aún no has publicado nada, vamos pon a chambear a nuestro amigo!!',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 16),
                _CircleButton(
                  icon: Icons.arrow_outward,
                  background: Colors.black,
                  foreground: Colors.white,
                  onTap: onPublish,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Mascot(pose: MascotPose.sleeping, height: _mascotHeight),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        'Publicaciones',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: context.appColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FeedPost extends ConsumerWidget {
  const _FeedPost({required this.publication, required this.currentUserId});

  final Publication publication;
  final String? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appColors;
    final images = publication.images;
    final isOwn = publication.authorId == currentUserId;
    // `perfiles/{uid}` es el documento con el nombre corto: `usuarios/{uid}`
    // guarda el nombre completo pero solo lo puede leer su dueño. Es el mismo
    // provider que usa la ficha de publicación, así el feed y el detalle no
    // pueden mostrar nombres distintos de la misma persona.
    //
    // Se pide también para las publicaciones propias: mirar el perfil propio
    // cuesta lo mismo que mirar el de cualquiera, y condicionar el `watch`
    // haría que Riverpod cambiara de dependencia según el post.
    final shortName = ref.watch(publicProfileProvider(publication.authorId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Row(
            children: [
              // Avatar y nombre son un solo objetivo: abren el perfil público de
              // quien publicó. Se hace con el avatar dentro porque el gesto
              // natural es "quiero saber quién es", y la inicial por sí sola no
              // parece pulsable.
              //
              // `GestureDetector` y no `InkWell`: el `Scaffold` lo aporta el
              // shell, y un `InkWell` sin `Material` ancestro revienta al
              // montar.
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          PublicProfilePage(userId: publication.authorId),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: palette.surface,
                        child: Text(
                          _initial(shortName.value?.shortName),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: palette.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isOwn ? 'Tú' : _authorName(shortName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // La edad de la publicación se fue al título: aquí el borde
              // derecho lo ocupa la acción de reportar, que solo aparece en
              // publicaciones ajenas porque nadie reporta lo suyo.
              if (!isOwn) _ReportButton(publication: publication),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          // El toque sobre las fotos recorre la galería; abrir el detalle se
          // hace desde el título, que es un objetivo más claro y no compite
          // por el mismo gesto.
          child: _StackedCards(images: images),
        ),
        _PostActions(publicationId: publication.id, isOwn: isOwn),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          // `GestureDetector` y no `InkWell`: este título vive dentro del
          // `Scaffold` del shell, pero la página no trae el suyo y un
          // `InkWell` sin `Material` ancestro revienta al montar.
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PublicationDetailPage(initial: publication),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      publication.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (_postHashtags(publication).isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
            // Un solo `Text` con separadores, no un `Wrap` de etiquetas: los
            // hashtags son texto informative aquí, y un `Wrap` se rompería en
            // varias líneas a media palabra en pantallas angostas.
            child: Text(
              // El prefijo se arma en la lista, no en el `Text`, para que el
              // resultado sea `#a #b #c` y no `#a#b#c`.
              _postHashtags(publication).map((tag) => '#$tag').join('  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.hashtag,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        _PostDescription(
          text: publication.description,
          style:
              Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: palette.textSecondary) ??
              const TextStyle(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Text(
            timeAgo(publication.publishedAt),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: palette.textSecondary),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

/// Bandera para reportar la publicación (HU19). Abre la hoja con los motivos y
/// avisa con un `SnackBar` cuando el reporte queda registrado.
///
/// Va en la cabecera, donde estaba la edad, porque es la única acción de la
/// tarjeta que no va con las demás: reportar no juzga la publicación, la
/// señala.
class _ReportButton extends StatelessWidget {
  const _ReportButton({required this.publication});

  final Publication publication;

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;

    return Semantics(
      button: true,
      label: 'Reportar publicación',
      excludeSemantics: true,
      container: true,
      child: GestureDetector(
        // `GestureDetector` y no `IconButton`: la tarjeta vive en el
        // `Scaffold` del shell y el `IconButton` pinta con el color de
        // disabled cuando el tapped se cancela.
        onTap: () => reportPublication(context, publication: publication),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // El ícono mide 20 px; el relleno es lo que le da un área de toque
          // usable sin agrandar la cabecera.
          padding: const EdgeInsets.fromLTRB(10, 6, 0, 6),
          child: Icon(
            Icons.flag_outlined,
            size: 20,
            color: palette.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Barra de acciones bajo las fotos: solo "me encanta", en el extremo derecho.
///
/// El estado es local de la sesión, vive en [postReactionsProvider] y no se
/// guarda. Ver [PostReactionsNotifier] para por qué vive fuera de la tarjeta.
///
/// En las publicaciones propias el botón se ve atenuado y no responde: nadie
/// marca su propia publicación.
class _PostActions extends ConsumerWidget {
  const _PostActions({required this.publicationId, required this.isOwn});

  final String publicationId;
  final bool isOwn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reaction = ref.watch(postReactionsProvider)[publicationId];
    final notifier = ref.read(postReactionsProvider.notifier);

    final bar = Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      // `Align` y no una `Row` con `Spacer`: con un solo botón la fila no
      // aporta nada y solo sirve para tener algo que separar.
      child: Align(
        alignment: Alignment.centerRight,
        child: _ActionButton(
          icon: Icons.favorite,
          semanticLabel: 'Me encanta',
          active: reaction?.loved ?? false,
          enabled: !isOwn,
          onTap: () => notifier.toggleLoved(publicationId),
        ),
      ),
    );

    // Atenúa la barra entera: el botón deja de leerse como disponible de un
    // vistazo.
    return isOwn ? Opacity(opacity: 0.4, child: bar) : bar;
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.semanticLabel,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;
    // El activo va en el azul de los hashtags: es el mismo color con el que se
    // pintan los hashtags de la tarjeta.
    final color = active ? AppColors.hashtag : palette.textSecondary;

    return Semantics(
      button: true,
      enabled: enabled,
      selected: active,
      label: semanticLabel,
      excludeSemantics: true,
      // Nodo propio: sin esto el botón se fusiona con el bloque de texto de la
      // tarjeta y su acción de "tocar" pasa a cubrir el post entero, no solo el
      // ícono.
      container: true,
      child: GestureDetector(
        // `GestureDetector` y no `InkWell`: la tarjeta vive en el `Scaffold`
        // del shell sin `Material` propio, y un `InkWell` sin `Material`
        // ancestro revienta al montar.
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // El padding holgado es lo que da el área de toque: el ícono solo
          // mide 22 px y por debajo de ~48 px el táctil no lo registra bien.
          padding: const EdgeInsets.all(12),
          child: AnimatedScale(
            scale: active ? 1.12 : 1,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: Icon(icon, size: 22, color: color),
          ),
        ),
      ),
    );
  }
}

/// Descripción del post: dos líneas y "..más" al final cuando el texto no
/// cabe. Al tocarla se despliega entera y muestra "..menos" para volver a
/// plegarla. El recorte se calcula con un [TextPainter] en lugar de apoyarse en
/// el `ellipsis` de [Text] porque el `ellipsis` se comería el propio "..más":
/// iría al final de la última línea visible, que es justo donde no queda sitio.
class _PostDescription extends StatefulWidget {
  const _PostDescription({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_PostDescription> createState() => _PostDescriptionState();
}

class _PostDescriptionState extends State<_PostDescription> {
  static const int _maxLines = 2;
  static const String _more = '...más';
  static const String _less = '...menos';

  bool _expanded = false;

  @override
  void didUpdateWidget(covariant _PostDescription oldWidget) {
    // El feed se reordena y recicla tarjetas: si la publicación cambió, el
    // plegado que había ya no corresponde a este texto.
    if (oldWidget.text != widget.text) _expanded = false;
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    if (text.isEmpty) return const SizedBox.shrink();

    // `LayoutBuilder` dentro del `Padding`, no al revés: el ancho hay que medirlo
    // sobre el espacio que realmente ocupa el texto. Midiendo el ancho del
    // contenedor sobran 40 px, el texto se medía como si entrara, y las
    // descripciones que llenaban las dos líneas se recortaban en silencio: sin
    // "..más" y sin puntos suspensivos.
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
            // `GestureDetector` y no `InkWell`: igual que el título, esta
            // tarjeta vive en el `Scaffold` del shell sin `Material` propio.
            onTap: isTruncated
                ? () => setState(() => _expanded = !_expanded)
                : null,
            // Semilla estable para el modo compacto: cambia la etiqueta sin
            // cambiar el árbol ni volver a crearlo.
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

  /// Devuelve [text] tal cual si cabe en [_maxLines] líneas; si no, el texto
  /// recortado en un límite de palabra. El sufijo lo pone quien llama, para que
  /// pueda ser "..más" o "..menos" según el estado.
  String _fold(double width) {
    final text = widget.text;
    final style = widget.style;
    final direction = Directionality.of(context);

    // Se mide el ancho de "..más" y se resta antes de componer el cuerpo: si no,
    // el texto se llenaría las dos líneas enteras y el sufijo se saldría.
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

    // Posición del cursor al final de la última línea que sí se compuso, y de
    // ahí el comienzo de la palabra que quedó partida.
    final end = painter.getPositionForOffset(
      Offset(painter.width, lines.last.baseline),
    );
    final wordStart = painter.getWordBoundary(end).start;
    // Una sola palabra más larga que la línea no tiene límite previo: en ese
    // caso se corta justo donde el motor dejó de dibujar en vez de no cortar.
    final cut = wordStart > 0 ? wordStart : end.offset;
    if (cut <= 0 || cut >= text.length) return text;

    return text.substring(0, cut).trimRight();
  }
}

/// Mazo de tarjetas: la de encima muestra la foto actual y la de atrás asoma
/// por debajo a la derecha, como en la referencia. Al tocarla la foto de
/// atrás pasa al frente con un deslizamiento, así también se ven las que
/// quedan tapadas.
class _StackedCards extends StatefulWidget {
  const _StackedCards({required this.images});

  final List<String> images;

  @override
  State<_StackedCards> createState() => _StackedCardsState();
}

class _StackedCardsState extends State<_StackedCards>
    with SingleTickerProviderStateMixin {
  /// Proporción de la foto: más alta que ancha. Antes la tarjeta era apaisada
  /// (alto fijo de 300 contra todo el ancho) y las imágenes salían recortadas
  /// por los lados en vez de respiradas.
  static const double _aspect = 1.2;

  /// Margen extra a cada lado, además del padding de la columna. Se descuenta
  /// del ancho disponible, así la foto nunca toca los bordes de la pantalla.
  static const double _sideMargin = 24;

  /// Tope de altura para que en tablets o muy anchas no se vuelva un bloque
  /// gigante que empuja el resto del post fuera de la vista.
  static const double _maxHeight = 440;

  /// Holgura vertical para que la sombra y la rotación no se corten.
  static const double _verticalSlack = 16;

  late final AnimationController _slide;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
      // Antes estaba en 1: eso mostraba la foto de atrás desde el inicio
      // (y con una sola foto no se veía nada). Reposo = 0.
    );
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
    required double w,
    required double h,
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
              width: w,
              height: h,
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

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final n = images.length;
    final canCycle = n > 1;

    final current = n == 0 ? null : images[_index];
    final behind = canCycle ? images[(_index + 1) % n] : null;
    final afterNext = canCycle ? images[(_index + 2) % n] : null;

    // El `LayoutBuilder` va por fuera porque la altura sale del ancho: en una
    // columna sin alto acotado no se puede fijar un alto fijo y al mismo tiempo
    // dejar que la tarjeta crezca con el ancho de la pantalla.
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = constraints.maxWidth - _sideMargin;
        final cardH = math.min(cardW * _aspect, _maxHeight);

        // `Center` porque las tarjetas se dibujan explícitas a `cardW`, más
        // angostas que el espacio disponible: sin esto quedan pegadas al
        // borde izquierdo en vez de centradas en la pantalla.
        return Center(
          child: SizedBox(
            width: cardW,
            height: cardH + _verticalSlack,
            child: GestureDetector(
              key: const Key('stacked-cards'),
              onTap: canCycle ? _advance : null,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 550),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) {
                  return AnimatedBuilder(
                    animation: _slide,
                    builder: (context, _) {
                      final p = Curves.easeInOutCubic.transform(_slide.value);
                      final swing = math.sin(math.pi * p); // 0 → 1 → 0

                      // Tarjeta que se va al fondo (la actual).
                      final outgoing = current == null
                          ? null
                          : _card(
                              url: current,
                              w: cardW,
                              h: cardH,
                              angle: (_lerp(-0.06, 0.12, p) - 0.10 * swing) * t,
                              scale: _lerp(1.0, 0.95, p),
                              offset: Offset(-cardW * 0.65 * swing, 0),
                              // Al llegar al fondo se desvanece y deja ver la
                              // que realmente queda asomando (afterNext).
                              opacity: p < 0.75 ? 1 : 1 - (p - 0.75) / 0.25,
                              dimmed: p > 0.5,
                              elevation: _lerp(1.0, 0.6, p),
                            );

                      // Tarjeta que avanza al frente.
                      final incoming = behind == null
                          ? null
                          : _card(
                              url: behind,
                              w: cardW,
                              h: cardH,
                              angle: _lerp(0.12, -0.06, p) * t,
                              scale: _lerp(0.95, 1.0, p),
                              offset: Offset.zero,
                              opacity: 1,
                              dimmed: p < 0.5,
                              elevation: _lerp(0.6, 1.0, p),
                            );

                      // Tarjeta escondida que pasará a ser la de atrás.
                      final hidden = afterNext == null
                          ? null
                          : _card(
                              url: afterNext,
                              w: cardW,
                              h: cardH,
                              angle: 0.12 * t,
                              scale: 0.95,
                              offset: Offset.zero,
                              opacity: 1,
                              dimmed: true,
                              elevation: 0.6,
                            );

                      return Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          if (hidden != null) hidden,
                          // El cruce de orden ocurre a mitad de animación.
                          if (p < 0.5) ...[
                            if (incoming != null) incoming,
                            if (outgoing != null) outgoing,
                          ] else ...[
                            if (outgoing != null) outgoing,
                            if (incoming != null) incoming,
                          ],
                          if (canCycle)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 10,
                              child: _PhotoDots(
                                key: const Key('photo-dots'),
                                count: n,
                                active: _index,
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Indicador de posición: solo aparece cuando hay más de una foto, porque si no
/// no hay nada que avanzar.
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
            color: Colors.black.withOpacity(0.18 * elevation),
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
            if (dimmed) Container(color: Colors.black.withOpacity(0.25)),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: foreground, size: 22),
        ),
      ),
    );
  }
}
