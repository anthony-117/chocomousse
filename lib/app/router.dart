import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/assistant/presentation/assistant_screen.dart';
import '../features/discover/presentation/discover_screen.dart';
import '../features/plans/presentation/plans_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/shell/app_shell.dart';

/// Top-level destinations, in the order shown by the floating nav and the web header.
enum AppTab {
  discover('/discover', 'Discover'),
  plans('/plans', 'Plans'),
  assistant('/assistant', 'Assistant'),
  profile('/profile', 'Profile');

  const AppTab(this.path, this.label);

  final String path;
  final String label;
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppTab.discover.path,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: AppTab.discover.path, builder: (context, state) => const DiscoverScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppTab.plans.path, builder: (context, state) => const PlansScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppTab.assistant.path, builder: (context, state) => const AssistantScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppTab.profile.path, builder: (context, state) => const ProfileScreen())],
          ),
        ],
      ),
    ],
  );
});
