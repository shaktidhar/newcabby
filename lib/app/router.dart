// lib/app/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/shell/scaffold_nav.dart';
import '../features/rides/presentation/rides_search_page.dart';
import '../features/rides/presentation/rides_results_page.dart';
import '../features/checkout/ride_checkout_page.dart';
import '../features/account/presentation/account_page.dart';

final GoRouter router = GoRouter(
  initialLocation: '/rides',
  routes: <RouteBase>[
    StatefulShellRoute.indexedStack(
      builder:
          (
            BuildContext context,
            GoRouterState state,
            StatefulNavigationShell navigationShell,
          ) {
            return ScaffoldWithNavBar(navigationShell: navigationShell);
          },
      branches: <StatefulShellBranch>[
        // BRANCH 0: Rides
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/rides',
              builder: (BuildContext context, GoRouterState state) =>
                  const RidesSearchPage(),
              routes: <RouteBase>[
                GoRoute(
                  path: 'results',
                  builder: (BuildContext context, GoRouterState state) =>
                      const RidesResultsPage(),
                ),
                GoRoute(
                  path: 'checkout',
                  builder: (BuildContext context, GoRouterState state) =>
                      const RideCheckoutPage(),
                ),
              ],
            ),
          ],
        ),

        // BRANCH 1: Account
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/account',
              builder: (BuildContext context, GoRouterState state) =>
                  const AccountPage(),
            ),
          ],
        ),
      ],
    ),
  ],
);
