import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  int _indexForLocation(String location) {
    if (location.startsWith('/events')) return 1;

    // ✅ treat /uploads as legacy alias of /gallery
    if (location.startsWith('/gallery') || location.startsWith('/uploads')) return 2;

    if (location.startsWith('/profile')) return 3;
    return 0; // home
  }

  void _goForIndex(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
        return;
      case 1:
        context.go('/events');
        return;
      case 2:
        context.go('/gallery');
        return;
      case 3:
        context.go('/profile');
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _indexForLocation(location);

    return Scaffold(
      backgroundColor: AppTokens.bg,
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => _goForIndex(context, i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTokens.ink,
        unselectedItemColor: AppTokens.subInk,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), label: 'Events'),
          BottomNavigationBarItem(icon: Icon(Icons.video_library_outlined), label: 'Gallery'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}