import 'package:flutter/material.dart';

import '../features/clipboard/presentation/clipboard_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/lan_transfer/presentation/lan_transfer_screen.dart';
import '../features/notes/presentation/notes_screen.dart';
import '../features/pomodoro/presentation/pomodoro_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/todos/presentation/todo_screen.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  int _selectedIndex = 0;

  static const _destinations = <_QingZaiDestination>[
    _QingZaiDestination(
      label: '首页',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      title: '轻载',
      screen: DashboardScreen(),
    ),
    _QingZaiDestination(
      label: '待办',
      icon: Icons.check_circle_outline,
      selectedIcon: Icons.check_circle,
      title: '待办事项',
      screen: TodoScreen(),
    ),
    _QingZaiDestination(
      label: '剪切板',
      icon: Icons.content_paste_outlined,
      selectedIcon: Icons.content_paste,
      title: '剪切板同步',
      screen: ClipboardScreen(),
    ),
    _QingZaiDestination(
      label: '笔记',
      icon: Icons.sticky_note_2_outlined,
      selectedIcon: Icons.sticky_note_2,
      title: '桌面笔记与备忘录',
      screen: NotesScreen(),
    ),
    _QingZaiDestination(
      label: '番茄钟',
      icon: Icons.timer_outlined,
      selectedIcon: Icons.timer,
      title: '番茄钟',
      screen: PomodoroScreen(),
    ),
    _QingZaiDestination(
      label: '传输',
      icon: Icons.lan_outlined,
      selectedIcon: Icons.lan,
      title: '局域网传输',
      screen: LANTransferScreen(),
    ),
    _QingZaiDestination(
      label: '设置',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      title: '设置',
      screen: SettingsScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = _destinations[_selectedIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 900;

        return Scaffold(
          appBar: AppBar(title: Text(selected.title)),
          body: Row(
            children: [
              if (useRail)
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onDestinationSelected,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final destination in _destinations)
                      NavigationRailDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: Text(destination.label),
                      ),
                  ],
                ),
              Expanded(child: selected.screen),
            ],
          ),
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onDestinationSelected,
                  destinations: [
                    for (final destination in _destinations)
                      NavigationDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: destination.label,
                      ),
                  ],
                ),
        );
      },
    );
  }

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
  }
}

class _QingZaiDestination {
  const _QingZaiDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.title,
    required this.screen,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String title;
  final Widget screen;
}
