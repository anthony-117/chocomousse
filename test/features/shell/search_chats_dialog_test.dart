import 'package:chocomousse/app/theme/app_theme.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/features/shell/search_chats_dialog.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers.dart';
import '../../itinerary/fakes.dart';
import '../chat/fakes.dart';

FakeChatApi _api() => FakeChatApi(
  chats: [
    chatJson(title: 'Jazz in Rome'),
    chatJson(id: 'c2', title: 'Lisbon'),
  ],
)..plans = [summaryJson(name: 'Jazz week in Rome')];

/// A page with a button that opens Search chats, in a router.
Future<(GoRouter, ProviderContainer)> _host(WidgetTester tester, FakeChatApi api, {Size size = desktop}) async {
  final router = GoRouter(
    initialLocation: '/start',
    routes: [
      for (final path in ['/', '/start', '/chat/:id'])
        GoRoute(
          path: path,
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                Text('page ${state.uri.path}'),
                TextButton(onPressed: () => showSearchChats(context), child: const Text('Search')),
              ],
            ),
          ),
        ),
    ],
  );
  addTearDown(router.dispose);
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: noRetry,
      overrides: chatApiOverrides(api),
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Search'));
  await tester.pumpAndSettle();
  return (router, ProviderScope.containerOf(tester.element(find.byType(SearchChatsView))));
}

Future<void> _type(WidgetTester tester, String q) async {
  await tester.enterText(find.descendant(of: find.byType(SearchChatsView), matching: find.byType(TextField)), q);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('asks for 2 letters, then shows chats and plans; a chat opens', (tester) async {
    final api = _api();
    final (router, _) = await _host(tester, api);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Type at least 2 letters'), findsOneWidget);

    await _type(tester, 'j');
    expect(find.text('Type at least 2 letters'), findsOneWidget);
    expect(api.searches, isEmpty);

    await _type(tester, 'jazz');
    expect(find.text('CHATS'), findsOneWidget);
    expect(find.text('PLANS'), findsOneWidget);
    expect(find.text('Lisbon'), findsNothing);
    expect(find.text('Jazz week in Rome'), findsOneWidget);

    await tester.tap(find.text('Jazz in Rome'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchChatsView), findsNothing);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/chat/c1');
  });

  testWidgets('a plan opens in the Plan pane of a new home', (tester) async {
    final (router, container) = await _host(tester, _api());
    await _type(tester, 'week');
    await tester.tap(find.text('Open plan'));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/');
    final panel = container.read(sidePanelProvider(homePanelKey));
    expect((panel.open, panel.pane, panel.planId), (true, PanelPane.plan, 'p1'));
  });

  testWidgets('says when nothing is found', (tester) async {
    await _host(tester, _api());
    await _type(tester, 'qq');
    expect(find.text("Nothing found for 'qq'"), findsOneWidget);
  });

  testWidgets('a search that fails offers Try again', (tester) async {
    final api = _api()..failSearch = Exception('down');
    await _host(tester, api);
    await _type(tester, 'lis');
    expect(find.text("Couldn't search your chats."), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Lisbon'), findsOneWidget);
  });

  testWidgets('before any chat it says there is nothing to search', (tester) async {
    await _host(tester, FakeChatApi());
    expect(find.text('Nothing to search yet.'), findsOneWidget);
  });

  testWidgets('on phones it fills the screen and Close shuts it', (tester) async {
    await _host(tester, _api(), size: phone);
    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.insetPadding, EdgeInsets.zero, reason: 'Dialog.fullscreen');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchChatsView), findsNothing);
  });
}
