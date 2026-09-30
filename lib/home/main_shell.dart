import 'package:bumble/constants/app_colors.dart';
import 'package:bumble/home/home_screen.dart';
import 'package:bumble/profile/profile_tab_screen.dart';
import 'package:bumble/screens/match_screen.dart';
import 'package:bumble/services/match_chat_service.dart';
import 'package:flutter/material.dart';

/// Node flowchart: "Home (Bottom Navigation)".
///
/// CATATAN TIM: node ini milik Kenzie. File ini sengaja dibuat minimal
/// supaya tab Profile punya tempat untuk menempel. Kalau Kenzie sudah
/// punya shell sendiri, cukup tambahkan `ProfileTabScreen()` sebagai
/// tab ketiga di shell miliknya dan file ini boleh dihapus.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final List<Widget> _tabs = const [
    HomeScreen(),
    MatchChatScreen(),
    ProfileTabScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          if (i == 1) MatchChatService.notifyMatchesChanged();
        },
        indicatorColor: AppColors.primary.withValues(alpha: 0.35),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: 'Swipe',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Match',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
