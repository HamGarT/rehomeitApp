import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/publishing/presentation/photos_step.dart';
import '../features/publishing/presentation/publish_draft_notifier.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const _publishIndex = 2;

  int _selectedIndex = 0;

  static const _sections = <({String title, String pending})>[
    (title: 'Explorar', pending: 'HU08'),
    (title: 'Campañas', pending: 'HU15, HU16, HU17'),
    (title: 'Publicar', pending: ''),
    (title: 'Mensajes', pending: 'HU09'),
    (title: 'Mi perfil', pending: 'HU18, HU20'),
  ];

  @override
  Widget build(BuildContext context) {
    final section = _sections[_selectedIndex];

    return Scaffold(
      appBar: AppBar(title: Text(section.title)),
      body: Center(
        child: Text('Pendiente de implementar: ${section.pending}'),
      ),
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
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PhotosStep()),
      );
      return;
    }
    setState(() => _selectedIndex = index);
  }
}
