import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/auth_controller.dart';
import '../features/campaigns/presentation/campaigns_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/notifications/data/notifications_repository.dart';
import '../features/messaging/presentation/messages_page.dart';
import '../features/delivery/data/delivery_repository.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/publishing/presentation/form_step.dart';
import '../features/publishing/presentation/mode_step.dart';
import '../features/publishing/presentation/photos_step.dart';
import '../features/publishing/presentation/publish_draft_notifier.dart';
import '../shared/widgets/app_dialog.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  static const _homeIndex = 0;
  static const _campaignsIndex = 1;
  static const _publishIndex = 2;
  static const _messagesIndex = 3;
  static const _perfilIndex = 4;

  int _selectedIndex = 0;
  final Set<String> _displayedNotifications = {};
  Timer? _pendingSyncTimer;
  bool _syncingPendingDelivery = false;
  bool _pendingDeliveryNoticeShown = false;

  static const _sections = <({String title, String pending})>[
    (title: 'Inicio', pending: ''),
    (title: 'Campañas', pending: 'HU15, HU16, HU17'),
    (title: 'Publicar', pending: ''),
    (title: 'Mensajes', pending: ''),
    (title: 'Mi perfil', pending: ''),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPendingDelivery());
    _pendingSyncTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _syncPendingDelivery(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pendingSyncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncPendingDelivery();
  }

  @override
  Widget build(BuildContext context) {
    final section = _sections[_selectedIndex];
    final userId = ref.watch(authStateProvider).value?.uid;
    if (userId != null) {
      ref.listen(unreadNotificationsProvider(userId), (previous, next) {
        final notifications = next.value ?? const [];
        for (final notification in notifications) {
          if (!_displayedNotifications.add(notification.id)) continue;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(notification.message)));
          // Si el marcado falla (sin conexión), la notificación vuelve a
          // mostrarse en el próximo arranque; no amerita interrumpir al usuario.
          ref
              .read(notificationsRepositoryProvider)
              .markAsRead(notification.id)
              .catchError((Object _) {});
        }
      });
    }

    return Scaffold(
      // Inicio trae su propia SliverAppBar con la marca y el buscador, así que
      // el AppBar del shell se reserva para las demás secciones.
      appBar: _selectedIndex == _homeIndex
          ? null
          : AppBar(title: Text(section.title)),
      body: switch (_selectedIndex) {
        _homeIndex => const HomePage(),
        _campaignsIndex => const CampaignsPage(),
        _messagesIndex => const MessagesPage(),
        _perfilIndex => const ProfilePage(),
        _ => Center(
          child: Text('Pendiente de implementar: ${section.pending}'),
        ),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: 'Campañas',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Publicar',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Mensajes',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  Future<void> _syncPendingDelivery() async {
    if (_syncingPendingDelivery) return;
    final userId = ref.read(authStateProvider).value?.uid;
    if (userId == null) return;
    _syncingPendingDelivery = true;
    try {
      final repository = ref.read(deliveryRepositoryProvider);
      final count = await repository.synchronizePending(userId);
      final remaining = await repository.pendingCount(userId);
      if (count > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count == 1
                  ? 'La entrega pendiente se sincronizó correctamente.'
                  : 'Se sincronizaron $count entregas pendientes.',
            ),
          ),
        );
      }
      if (remaining > 0 && !_pendingDeliveryNoticeShown && mounted) {
        _pendingDeliveryNoticeShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tienes una entrega pendiente de sincronización. Conservaremos sus datos y fotografía en este dispositivo.',
            ),
          ),
        );
      } else if (remaining == 0) {
        _pendingDeliveryNoticeShown = false;
      }
    } catch (_) {
      // La operación permanece en disco para el siguiente reintento.
    } finally {
      _syncingPendingDelivery = false;
    }
  }

  void _onDestinationSelected(int index) {
    if (index == _publishIndex) {
      _openPublishing();
      return;
    }
    setState(() => _selectedIndex = index);
  }

  /// Un borrador con fotografías se conserva hasta que la persona decida
  /// (HU03-19): la confirmación que falló por falta de red se reintenta desde
  /// el paso donde quedó. Cerrar el diálogo sin elegir no toca nada.
  Future<void> _openPublishing() async {
    final navigator = Navigator.of(context);
    final draft = ref.read(publishDraftProvider);
    if (draft.photosCompleted) {
      final resume = await showDialog<bool>(
        context: context,
        builder: (context) => AppDialog(
          title: 'Tienes una publicación sin confirmar',
          subtitle: 'Puedes continuar donde la dejaste o empezar una nueva.',
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Empezar de nuevo'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (!mounted || resume == null) return;
      if (resume) {
        // Los tres pasos apilados: se llega al último, donde falló la
        // confirmación, y "atrás" recorre los anteriores.
        navigator.push(MaterialPageRoute(builder: (_) => const PhotosStep()));
        navigator.push(MaterialPageRoute(builder: (_) => const FormStep()));
        navigator.push(MaterialPageRoute(builder: (_) => const ModeStep()));
        return;
      }
    }
    ref.read(publishDraftProvider.notifier).reset();
    navigator.push(MaterialPageRoute(builder: (_) => const PhotosStep()));
  }
}
