import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/domain/publication.dart';
import '../../../shared/widgets/mascot.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../explore/presentation/explore_controller.dart';
import '../domain/profile_summary.dart';
import 'profile_controller.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_sections.dart';
import 'widgets/profile_stats.dart';

/// Perfil público de otra persona (HU20, criterios 12 a 20).
///
/// Se llega desde el detalle de una publicación.
///
/// Lo que esta pantalla NO hace es deliberado, no una omisión pendiente:
/// - No muestra el correo ni el teléfono. `perfiles/{uid}` no los trae, y aquí
///   tampoco se lee `usuarios/{uid}`, que solo su dueño puede ver (c. 16).
/// - No muestra aportes a campañas ni compromisos como voluntario (c. 19): son
///   datos propios que aún no tienen dónde guardarse.
/// - No ofrece iniciar una conversación (c. 20): esa se abre desde el detalle de
///   la publicación, donde está el contexto de por qué se habla.
class PublicProfilePage extends ConsumerWidget {
  const PublicProfilePage({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `perfiles/{uid}` solo se puede leer con sesión iniciada, así que un
    // visitante sin sesión no tiene nada que mirar aquí. Se dice antes de
    // disparar la consulta en vez de dejar que falle y se pinte el aviso de
    // error, que habla de un problema de red donde no lo hay.
    final signedIn = ref.watch(authStateProvider).value != null;
    if (!signedIn) {
      return const Scaffold(
        appBar: _PublicProfileAppBar(),
        body: _SessionRequired(),
      );
    }

    final profile = ref.watch(publicProfileProvider(userId));
    final publications = ref.watch(profilePublicationsProvider(userId));

    return Scaffold(
      appBar: const _PublicProfileAppBar(),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(profilePublicationsProvider(userId)),
        child: CustomScrollView(
          // Sin esto el indicador de recarga no aparece nunca: un perfil con dos
          // publicaciones no da para desplazarse.
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: ProfileHeader(
                // Nombre corto y nunca el completo (D07, HU20 criterio 13).
                name: profile.value?.shortName ?? '',
                district: profile.value?.district ?? '',
                joinedAt: profile.value?.joinedAt,
                isOwn: false,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            // Los contadores y la lista salen de la misma consulta y en el mismo
            // `when`: calcular los contadores aparte los haría parpadear en cero
            // mientras cargan, y además podrían contar filas que la lista no
            // muestra.
            ..._publicationSlivers(publications),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  List<Widget> _publicationSlivers(AsyncValue<List<Publication>> publications) {
    return publications.when(
      loading: () => const [
        SliverToBoxAdapter(child: _StatsSkeleton()),
        ProfileLoadingSliver(),
      ],
      // `perfiles/{uid}` exige sesión iniciada, así que un fallo aquí casi
      // siempre es una sesión vencida: se avisa en línea y se deja el resto del
      // perfil, que sí se pudo leer.
      error: (_, _) => const [
        SliverToBoxAdapter(child: _StatsSkeleton()),
        SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverToBoxAdapter(
          child: ProfileLoadError(
            message: 'No se pudieron cargar las publicaciones.',
          ),
        ),
      ],
      data: (items) {
        // Anuladas y retiradas no salen ni de la lista ni de los contadores: el
        // criterio 7 de HU19 las saca del listado, la búsqueda y el detalle, y
        // contarlas aquí las volvería visibles por la puerta de atrás.
        final visible = ProfileSummary.publicPublications(items);
        final summary = ProfileSummary.fromPublications(visible);

        // Con la lista vacía los contadores se muestran en cero, no como
        // esqueleto: "0 publicaciones" ya es el dato real y el esqueleto se
        // quedaría puesto para siempre.
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              // El perfil público lleva solo los dos contadores del
              // criterio 18: las entregas por confirmar son un dato de
              // seguimiento de la operación, no de lo que la persona puso a
              // disposición de otros.
              child: ProfileStats(
                stats: [
                  ProfileStat(
                    value: summary.publishedCount,
                    label: 'Publicadas',
                    semanticLabel: 'Publicaciones realizadas',
                  ),
                  ProfileStat(
                    value: summary.deliveriesConfirmed,
                    label: 'Confirmadas',
                    semanticLabel: 'Entregas confirmadas',
                  ),
                ],
              ),
            ),
          ),
          if (visible.isEmpty)
            // El texto no distingue entre "nunca publicó" y "retiró todo" a
            // propósito: desde aquí no se puede saber.
            const SliverToBoxAdapter(
              child: ProfileEmptyState(
                pose: MascotPose.wave,
                title: 'Nada por aquí',
                message:
                    'Esta persona todavía no tiene publicaciones disponibles.',
              ),
            )
          else
            ...profilePublicationSlivers(
              title: 'Publicaciones',
              items: visible,
            ),
        ];
      },
    );
  }
}

/// Ancla de los contadores mientras la lista carga o falla.ocupa el mismo alto
/// que la fila real para que la cabecera no salte al llegar los datos, y no
/// muestra ceros: "0 publicaciones" durante la carga es un dato falso.
class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    final border = Border.all(color: context.appColors.border);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: border,
        ),
        child: Row(
          children: [
            for (var index = 0; index < 2; index++) ...[
              if (index > 0)
                Container(
                  width: 1,
                  height: 34,
                  margin: const EdgeInsets.only(top: 4),
                  color: context.appColors.border,
                ),
              Expanded(
                child: Center(
                  child: Container(
                    width: 28,
                    height: 20,
                    decoration: BoxDecoration(
                      color: context.appColors.border,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Barra de la pantalla. Va en su propia clase para que el caso sin sesión y el
/// normal compartan exactamente el mismo título y el mismo botón de cerrar.
class _PublicProfileAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _PublicProfileAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(title: const Text('Perfil'));
}

class _SessionRequired extends StatelessWidget {
  const _SessionRequired();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 40,
            color: context.appColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'Inicia sesión para ver este perfil.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: context.appColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

