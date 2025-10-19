import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeShell extends StatefulWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          setState(() => index = i);
          switch (i) {
            case 0:
              context.go('/home/rides');
              break;
            // case 1: context.go('/home/tours'); break;
            // case 2: context.go('/home/trips'); break;
            // case 3: context.go('/home/account'); break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_taxi_outlined),
            label: 'Rides',
          ),
          // NavigationDestination(icon: Icon(Icons.tour_outlined), label: 'Tours'),
          // NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Trips'),
          // NavigationDestination(icon: Icon(Icons.person_outline), label: 'Account'),
        ],
      ),
    );
  }
}
