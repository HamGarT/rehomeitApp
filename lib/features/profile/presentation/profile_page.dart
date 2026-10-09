import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../app/theme_mode_notifier.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/domain/publication.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/button_spinner.dart';
import '../../../shared/widgets/mascot.dart';
import '../../auth/data/auth_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../delivery/presentation/delivery_controller.dart';
import '../../explore/presentation/explore_controller.dart';
import '../domain/profile_summary.dart';
import 'profile_controller.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_publication_tile.dart';
import 'widgets/profile_stats.dart';

/// Perfil propio: la actividad de la persona y sus ajustes (HU20, criterios 1 a
/// 6, 8 y 11).
///
/// El `Scaffold` y el `AppBar` los aporta el shell, así que esta pantalla
/// devuelve solo el cuerpo.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _signingOut = false;

  Future<void> _confirmSignOut() async {
    final confirmed = await showAppConfirmDialog(
      context,
      mascot: MascotPose.wave,
      title: '¿Te vas por ahora?',
      subtitle: 'Tu sesión se cerrará en este dispositivo. Tus publicaciones siguen en su lugar.',
      cancelLabel: 'Me quedo',
      confirmLabel: 'Cerrar sesión',
    );
    if (!confirmed || !mounted) return;

    setState(() => _signingOut = true);
    try {
      await ref.read(authControllerProvider.notifier).signOut();
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          friendlyAuthError(error),
          kind: AppSnackBarKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  void _refresh() => ref.invalidate(profilePublicationsProvider);

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final userId = user?.uid ?? '';
    final publications = ref.watch(profilePublicationsProvider(userId));
    final summary = ref.watch(profileSummaryProvider(userId));
    // El perfil público es la misma fuente que el propio. Se pide siempre,
    // incluso sin publicaciones: el nombre corto, el distrito y la fecha de
    // ingreso son lo único que se puede mostrar antes de publicar nada.
    final profile = ref.watch(publicProfileProvider(userId));

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: CustomScrollView(
        // Sin esto el indicador de recarga nunca aparece: el contenido de un
        // perfil recién creado no da para desplazarse.
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: ProfileHeader(
              name: _fullName(user?.displayName),
              district: profile.value?.district ?? '',
              joinedAt: profile.value?.joinedAt,
              isOwn: true,
              email: user?.email ?? '',
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ProfileStats(
                stats: _ownStats(summary),
                footer: ImpactSummary(kilograms: summary.avoidedKg),
              ),
            ),
          ),
          ..._ownPublicationSlivers(publications),
          ..._commitmentSlivers(userId),
          const SliverToBoxAdapter(child: _AppearanceSection()),
          const SliverToBoxAdapter(
            child: ProfileSectionHeader(title: 'Sesión'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: OutlinedButton.icon(
                onPressed: _signingOut ? null : _confirmSignOut,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.4),
                  ),
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: _signingOut
                    ? const ButtonSpinner(color: AppColors.error)
                    : const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
              // Aviso de por qué el correo no sale de aquí. Va al pie y no
              // junto al correo porque la línea también confirma que en el perfil
              // público no está.
              child: Text(
                'Tu correo no se muestra a otras personas. Solo lo ves tú.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  List<ProfileStat> _ownStats(ProfileSummary summary) => [
    ProfileStat(
      value: summary.publishedCount,
      label: 'Publicadas',
      semanticLabel: 'Publicaciones realizadas',
    ),
    ProfileStat(
      value: summary.deliveriesRegistered,
      label: 'Entregas',
      semanticLabel: 'Entregas registradas',
    ),
    ProfileStat(
      value: summary.deliveriesConfirmed,
      label: 'Confirmadas',
      semanticLabel: 'Entregas confirmadas',
    ),
  ];

  /// Historial propio. A diferencia del perfil público, aquí sí aparecen las
  /// anuladas y las retiradas: el recorrido de una publicación que se retiró
  /// forma parte del historial de quien la publicó (HU20, criterio 4).
  List<Widget> _ownPublicationSlivers(
    AsyncValue<List<Publication>> publications,
  ) {
    return publications.when(
      loading: () => [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      ],
      error: (_, _) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _InlineError(onRetry: _refresh),
          ),
        ),
      ],
      data: (items) {
        if (items.isEmpty) {
          return const [SliverToBoxAdapter(child: _NoPublicationsYet())];
        }
        return [
          SliverToBoxAdapter(
            child: ProfileSectionHeader(
              title: 'Mis publicaciones',
              trailing: '${items.length}',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return ProfilePublicationTile(
                  publication: item,
                  status: item.effectiveStatus(DateTime.now()),
                  isOwn: true,
                );
              },
            ),
          ),
        ];
      },
    );
  }

  /// Recojos asumidos como voluntario (HU10). Van aparte del historial porque
  /// no son publicaciones propias, y la sección se omite cuando no hay ninguno
  /// para no sumar un bloque vacío al perfil de quien nunca hizo voluntariado.
  List<Widget> _commitmentSlivers(String userId) {
    final items =
        ref.watch(volunteerCommitmentsProvider(userId)).value ??
        const <Publication>[];
    if (items.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: ProfileSectionHeader(
          title: 'Mis compromisos de recojo',
          trailing: '${items.length}',
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return ProfilePublicationTile(
              publication: item,
              status: item.effectiveStatus(DateTime.now()),
            );
          },
        ),
      ),
    ];
  }
}

String _fullName(String? displayName) {
  final name = displayName?.trim() ?? '';
  return name.isEmpty ? 'Usuario' : name;
}

/// Interruptor de modo oscuro. Vive en el perfil porque es el único ajuste de la
/// aplicación; si se muda a otra pantalla, nadie lo encuentra.
class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(darkModeProvider);
    final palette = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProfileSectionHeader(title: 'Apariencia'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Icon(
                  isDark ? Icons.dark_mode : Icons.light_mode_outlined,
                  size: 22,
                  color: palette.textSecondary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modo oscuro',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      Text(
                        isDark
                            ? 'Siguiendo la paleta oscura.'
                            : 'Siguiendo la paleta clara.',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: palette.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isDark,
                  onChanged: (value) =>
                      ref.read(darkModeProvider.notifier).setDark(value),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Estado vacío del historial: en lugar de dejar un hueco se ofrece empezar,
/// que es la única acción posible aquí.
class _NoPublicationsYet extends StatelessWidget {
  const _NoPublicationsYet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 8),
      child: Column(
        children: [
          // El GIF es vertical (136x220), así que se le da más alto que a una pose
          // horizontal para que no quede con un ancho desproporcionado.
          const Mascot(pose: MascotPose.sleeping, height: 170),
          const SizedBox(height: 16),
          Text(
            'Todavía no has publicado nada',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontFamily: 'FreckleFace',
              fontSize: 24,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Publica algo que ya no uses y dale un nuevo hogar. '
            'Aquí verás todo lo que vas donando.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: context.appColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Fallo al leer el historial. Va en línea y no en pantalla completa porque el
/// resto del perfil sí se leyó: el nombre, el distrito y los contadores no
/// dependen de esta consulta.
class _InlineError extends StatelessWidget {
  const _InlineError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No se pudo cargar tus publicaciones.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.appColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
