import 'package:flutter/material.dart';

import 'home_shell.dart';
import 'theme.dart';

class RehomeitApp extends StatelessWidget {
  const RehomeitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReHomeIt',
      theme: buildAppTheme(),
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: const HomeShell(),
    );
  }
}
