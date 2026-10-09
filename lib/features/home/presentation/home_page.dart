import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/domain/publication.dart';
import '../../../shared/widgets/mascot.dart';
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
import 'widgets/post_description.dart';
import 'widgets/stacked_cards.dart';

/// Abre el flujo de publicación. El shell también lo hace al pulsar la pestaña
/// "Publicar", así que el estado del borrador se reinicia en los dos casos.
void _startPublishing(WidgetRef ref) {
  ref.read(publishDraftProvider.notifier).reset();
  Navigator.of(ref.context)
      .push(MaterialPageRoute(builder: (_) => const PhotosStep()));
}

/// Normaliza un texto a hashtag: minúsculas, sin tildes ni signos y sin
/// espacios interiores. "Ropa de cama y abrigo" pasa a "ropadecamayabrigo",
/// porque un hashtag no admite espacios y se lee mejor pegado que con guiones.
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
/// Salen de la publicación y no de una lista propia, así el feed no puede
/// desincronizarse de lo que la persona publicó.
List<String> _postHashtags(Publication publication) {
  final raw = [
    publication.mode.wireValue,
    publication.category,
    publication.condition,
    publication.district,
  ];
  final seen = <String>{};
  final tags = <String>[];
  for (final value in raw) {
    final tag = _hashtagify(value);
    // Un valor repetido no produce "#ropainfantil #ropainfantil".
    if (tag.isEmpty || !seen.add(tag)) continue;
    tags.add(tag);
  }
  return tags;
}

/// Nombre de la cabecera del post. Mientras el perfil público no llega, o si
/// el documento no existe, se muestra un texto genérico. Nunca el uid: en la
/// cabecera es ruido para quien lee el feed.
String _authorName(AsyncValue<PublicProfile?> profile) {
  final shortName = profile.value?.shortName ?? '';
  if (shortName.trim().isEmpty) return 'Usuario de ReHomeIt';
  return shortName;
}

/// Inicial del avatar. Con el nombre vacío cae en "U" en vez de dejar el
/// icono de persona.
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
                  // `ExplorePage` no trae `Scaffold`: como pestaña lo sostiene
                  // el shell. Como ruta propia hay que dárselo, o las hojas de
                  // filtro fallan por falta de un `Material` ancestro.
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
            // El CTA dice "todavía no has publicado nada", así que solo tiene
            // sentido mientras la persona no tenga ninguna publicación propia.
            final hasOwn = data.publications.any((p) => p.authorId == userId);
            if (!hasOwn) {
              return SliverToBoxAdapter(
                child: _PublishCta(onPublish: startPublishing),
              );
            }
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          },
          // Mientras carga no se sabe si tiene publicaciones: se muestra para
          // que el contenido no salte al llegar los datos.
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

/// Tarjeta "publica algo": es el estado vacío del feed, así que solo aparece
/// cuando la persona todavía no tiene publicaciones.
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
                    color: AppColors.onAccent,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 16),
                // Sobre el amarillo, que es el mismo en claro y oscuro, el
                // botón va siempre negro con icono blanco.
                _CircleButton(
                  icon: Icons.arrow_outward,
                  background: AppColors.onAccent,
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

/// Una publicación del feed: cabecera con autor, fotos, reacción, título,
/// hashtags, descripción y antigüedad.
///
/// Los toques van con `GestureDetector` y no con `InkWell`: la página vive en
/// el `Scaffold` del shell sin `Material` propio, y un `InkWell` sin `Material`
/// ancestro revienta al montar.
class _FeedPost extends StatelessWidget {
  const _FeedPost({required this.publication, required this.currentUserId});

  final Publication publication;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final palette = context.appColors;
    final isOwn = publication.isAuthor(currentUserId ?? '');
    final hashtags = _postHashtags(publication);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PostHeader(publication: publication, isOwn: isOwn),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          // El toque sobre las fotos recorre la galería; abrir el detalle se
          // hace desde el título, para no competir por el mismo gesto.
          child: StackedCards(images: publication.images),
        ),
        _PostActions(publicationId: publication.id, isOwn: isOwn),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PublicationDetailPage(initial: publication),
              ),
            ),
            child: Text(
              publication.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (hashtags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
            // Un solo `Text` con separadores y no un `Wrap` de etiquetas: aquí
            // los hashtags son texto informativo, y un `Wrap` se partiría en
            // varias líneas en pantallas angostas.
            child: Text(
              hashtags.map((tag) => '#$tag').join('  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.hashtag,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        PostDescription(
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

/// Avatar y nombre de quien publicó, que juntos abren su perfil público, y la
/// bandera de reporte a la derecha en publicaciones ajenas.
class _PostHeader extends ConsumerWidget {
  const _PostHeader({required this.publication, required this.isOwn});

  final Publication publication;
  final bool isOwn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appColors;
    // `perfiles/{uid}` es el documento con el nombre corto; `usuarios/{uid}`
    // guarda el completo pero solo lo lee su dueño. Es el mismo provider que
    // usa el detalle, así feed y detalle no pueden mostrar nombres distintos.
    // Se pide también para las publicaciones propias: condicionar el `watch`
    // haría que Riverpod cambiara de dependencia según el post.
    final profile = ref.watch(publicProfileProvider(publication.authorId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Row(
        children: [
          // Avatar y nombre son un solo objetivo: la inicial por sí sola no
          // parece pulsable.
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
                      _initial(profile.value?.shortName),
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(color: palette.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isOwn ? 'Tú' : _authorName(profile),
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
          // Nadie reporta lo suyo.
          if (!isOwn) _ReportButton(publication: publication),
        ],
      ),
    );
  }
}

/// Bandera para reportar la publicación (HU19). Abre la hoja con los motivos.
/// Va en la cabecera porque es la única acción de la tarjeta que no va con las
/// demás: reportar no juzga la publicación, la señala.
class _ReportButton extends StatelessWidget {
  const _ReportButton({required this.publication});

  final Publication publication;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Reportar publicación',
      excludeSemantics: true,
      container: true,
      child: GestureDetector(
        onTap: () => reportPublication(context, publication: publication),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // El icono mide 20 px; el relleno le da un área de toque usable sin
          // agrandar la cabecera.
          padding: const EdgeInsets.fromLTRB(10, 6, 0, 6),
          child: Icon(
            Icons.flag_outlined,
            size: 20,
            color: context.appColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Barra de acciones bajo las fotos: solo "me encanta", a la derecha.
///
/// El estado es local de la sesión, vive en [postReactionsProvider] y no se
/// guarda. En las publicaciones propias el botón se ve atenuado y no responde:
/// nadie marca su propia publicación.
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

    // Se atenúa la barra entera para que el botón no se lea como disponible.
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
    // El activo va en el mismo azul que los hashtags de la tarjeta.
    final color = active ? AppColors.hashtag : context.appColors.textSecondary;

    return Semantics(
      button: true,
      enabled: enabled,
      selected: active,
      label: semanticLabel,
      excludeSemantics: true,
      // Nodo propio: sin esto el botón se fusiona con el bloque de texto y su
      // acción de "tocar" pasa a cubrir el post entero.
      container: true,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // El icono mide 22 px; por debajo de unos 48 px el táctil no lo
          // registra bien.
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
