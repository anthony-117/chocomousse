import 'package:chocomousse/app/theme/app_theme.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/features/account/application/session.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:chocomousse/features/side_panel/presentation/plan_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../account/fakes.dart';
import '../../helpers.dart';
import '../../itinerary/fakes.dart';
import '../chat/fakes.dart';

void main() {
  testWidgets("from the home's panel, a day question starts a chat that keeps the panel", (tester) async {
    final api = FakeChatApi();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: SizedBox(width: 520, height: 900, child: PlanPane(chatKey: homePanelKey)),
          ),
        ),
        GoRoute(path: '/chat/:id', builder: (context, state) => Text('chat ${state.pathParameters['id']}')),
      ],
    );
    addTearDown(router.dispose);
    tester.view
      ..physicalSize = desktop
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: noRetry,
        overrides: [
          ...chatApiOverrides(api),
          planRepositoryProvider.overrideWithValue(FakePlanRepository()),
          plansProvider.overrideWith((ref) => const PlanList(items: [], count: 0, max: 50)),
          profileProvider.overrideWith((ref) => defaultProfile()),
        ],
        child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      ),
    );
    final container = ProviderScope.containerOf(tester.element(find.byType(PlanPane)));
    container.read(sidePanelProvider(homePanelKey).notifier).openPlan('p1');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Alternatives to Trevi Fountain'));
    await tester.pumpAndSettle();
    expect(api.transport.posts.single.path, '/assistant/chats', reason: 'a new chat');
    expect(router.routerDelegate.currentConfiguration.uri.path, '/chat/c1');
    final panel = container.read(sidePanelProvider('c1'));
    expect((panel.open, panel.pane, panel.planId), (true, PanelPane.plan, 'p1'));
  });
}
