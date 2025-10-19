import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ScaffoldWithNavBar extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  void _goBranch(int index) {
    // Preserve state when switching tabs
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Simple adaptive nav: Rail for wide screens, Bar for narrow
        final useRail = constraints.maxWidth >= 1000;
        final destinations = const [
          NavigationDestination(
            icon: Icon(Icons.local_taxi_outlined),
            label: 'Rides',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Account',
          ),
        ];

        return Scaffold(
          body: Row(
            children: [
              if (useRail)
                NavigationRail(
                  selectedIndex: currentIndex,
                  onDestinationSelected: _goBranch,
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.local_taxi_outlined),
                      label: Text('Rides'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline),
                      label: Text('Account'),
                    ),
                  ],
                ),
              Expanded(child: widget.navigationShell),
            ],
          ),
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: currentIndex,
                  onDestinationSelected: _goBranch,
                  destinations: destinations,
                ),
        );
      },
    );
  }
}
