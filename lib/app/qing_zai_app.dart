import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'navigation_shell.dart';

class QingZaiApp extends StatelessWidget {
  const QingZaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '轻载 Qing Zai',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const NavigationShell(),
    );
  }
}
