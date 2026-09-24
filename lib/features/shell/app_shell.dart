import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kickly_logo.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  int _indexFor(String path) {
    if (path.startsWith('/matches')) return 1;
    if (path.startsWith('/stats')) return 2;
    if (path.startsWith('/profile')) return 3;
    return 0;
  }

  void _go(BuildContext context, int value) {
    switch (value) {
      case 0:
        context.go('/');
      case 1:
        context.go('/matches');
      case 2:
        context.go('/stats');
      case 3:
        context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final index = _indexFor(path);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final animatedChild = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(key: ValueKey(path), child: child),
    );

    if (wide) {
      return Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/matches/new'),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nuova partita'),
        ),
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: index,
                onDestinationSelected: (value) => _go(context, value),
                extended: MediaQuery.sizeOf(context).width >= 1180,
                minExtendedWidth: 220,
                leading: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 18, 12, 24),
                  child: MediaQuery.sizeOf(context).width >= 1180
                      ? const KicklyLogo(fontSize: 25)
                      : const KicklyLogo(fontSize: 28, showWordmark: false),
                ),
                destinations: const [
                  NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: Text('Home')),
                  NavigationRailDestination(icon: Icon(Icons.sports_soccer_outlined), selectedIcon: Icon(Icons.sports_soccer), label: Text('Partite')),
                  NavigationRailDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded), label: Text('Statistiche')),
                  NavigationRailDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: Text('Profilo')),
                ],
              ),
              const VerticalDivider(width: 1, color: AppColors.border),
              Expanded(child: animatedChild),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(child: animatedChild),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/matches/new'),
        child: const Icon(Icons.add_rounded),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => _go(context, value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.sports_soccer_outlined), selectedIcon: Icon(Icons.sports_soccer), label: 'Partite'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Profilo'),
        ],
      ),
    );
  }
}
