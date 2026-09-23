import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/auth_controller.dart';
import '../features/explore/presentation/explore_page.dart';
import '../features/notifications/data/notifications_repository.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/publishing/presentation/photos_step.dart';
import '../features/publishing/presentation/publish_draft_notifier.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const _publishIndex = 2;
  static const _perfilIndex = 4;
  static const _exploreIndex = 0;

  int _selectedIndex = 0;
  final Set<String> _displayedNotifications = {};

  static const _sections = <({String title, String pending})>[
    (title: 'Explorar', pending: ''),
    (title: 'Campañas', pending: 'HU15, HU16, HU17'),
    (title: 'Publicar', pending: ''),
    (title: 'Mensajes', pending: 'HU09'),
    (title: 'Mi perfil', pending: 'HU18, HU20'),
  ];

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
      appBar: AppBar(title: Text(section.title)),
      body: switch (_selectedIndex) {
        _exploreIndex => const ExplorePage(),
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

  void _onDestinationSelected(int index) {
    if (index == _publishIndex) {
      ref.read(publishDraftProvider.notifier).reset();
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const PhotosStep()));
      return;
    }
    setState(() => _selectedIndex = index);
  }
}
