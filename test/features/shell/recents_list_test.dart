import 'dart:async';

import 'package:chocomousse/app/theme/app_theme.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/core/widgets/skeleton.dart';
import 'package:chocomousse/features/shell/recents_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers.dart';
import '../chat/fakes.dart';

List<Map<String, Object?>> _chats(int n) => [for (var i = 1; i <= n; i++) chatJson(id: 'c$i', title: 'Chat $i')];

/// Recents beside a page, in a router, so opening and deleting really navigate.
Future<GoRouter> _host(
  WidgetTester tester,
  FakeChatApi api, {
  String initial = '/',
  ThemeMode mode = ThemeMode.light,
  bool settle = true,
}) async {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(
          body: Row(
            children: [
              SizedBox(width: 272, child: RecentsList(location: state.uri.path)),
              Expanded(child: child),
            ],
          ),
        ),
        routes: [
          for (final path in ['/', '/chat/:id'])
            GoRoute(path: path, builder: (context, state) => Text('page ${state.uri.path}')),
        ],
      ),
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
      overrides: chatApiOverrides(api),
      child: MaterialApp.router(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        routerConfig: router,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return router;
}

String _at(GoRouter router) => router.routerDelegate.currentConfiguration.uri.path;

Future<void> _menu(WidgetTester tester, String title, String action) async {
  await tester.tap(find.byTooltip('More for $title'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action).last);
  await tester.pumpAndSettle();
}

void main() {
  forBothModes('lists the chats by title, the open one active, and how long they are kept', (tester, mode) async {
    final api = FakeChatApi(
      chats: [
        ..._chats(2),
        chatJson(id: 'c3', title: null),
      ],
    )..keepDays = 60;
    final router = await _host(tester, api, initial: '/chat/c2', mode: mode);
    expect(find.text('RECENTS'), findsOneWidget);
    expect(find.text('Chat 1'), findsOneWidget);
    expect(find.text('New chat'), findsOneWidget, reason: 'a chat without a title');
    expect(find.text('Chats are kept for 60 days.'), findsOneWidget);
    expect(find.text('Show more'), findsNothing);
    expect(tester.getSemantics(find.bySemanticsLabel('Chat 2')), isSemantics(isSelected: true));

    await tester.tap(find.text('Chat 1'));
    await tester.pumpAndSettle();
    expect(_at(router), '/chat/c1');
  });

  testWidgets('Show more loads the next page', (tester) async {
    final api = FakeChatApi(chats: _chats(3), pageSize: 2);
    await _host(tester, api);
    expect(find.text('Chat 3'), findsNothing);
    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();
    expect(find.text('Chat 3'), findsOneWidget);
    expect(find.text('Show more'), findsNothing);
  });

  testWidgets('loading shows three skeleton rows; no chats hides Recents', (tester) async {
    final api = FakeChatApi()..gate = Completer<void>();
    await _host(tester, api, settle: false);
    await tester.pump();
    expect(find.byType(SkeletonBox), findsNWidgets(3));
    api.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('RECENTS'), findsNothing);
  });

  testWidgets('a list that fails offers Try again', (tester) async {
    final api = FakeChatApi(chats: _chats(1))..failList = Exception('down');
    await _host(tester, api);
    expect(find.text("Couldn't load your chats"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Chat 1'), findsOneWidget);
  });

  testWidgets('Rename takes 1–40 characters', (tester) async {
    final api = FakeChatApi(chats: _chats(1));
    await _host(tester, api);
    await _menu(tester, 'Chat 1', 'Rename');
    expect(find.text('1–40 characters'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save')).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Jazz weekend');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Jazz weekend'), findsOneWidget);
    expect(api.chats.single['title'], 'Jazz weekend');
  });

  testWidgets('a refused rename says so and keeps the title', (tester) async {
    final api = FakeChatApi(chats: _chats(1))..failRename = Exception('no');
    await _host(tester, api);
    await _menu(tester, 'Chat 1', 'Rename');
    await tester.enterText(find.byType(TextField), 'Other');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't rename this chat."), findsOneWidget);
    expect(find.text('Chat 1'), findsOneWidget);
  });

  testWidgets('Delete asks first; deleting the open chat goes home', (tester) async {
    final api = FakeChatApi(chats: _chats(2));
    final router = await _host(tester, api, initial: '/chat/c1');
    await _menu(tester, 'Chat 1', 'Delete');
    expect(find.text('Delete this chat?'), findsOneWidget);
    expect(find.text('Plans built in it stay.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.chats, hasLength(2));

    await _menu(tester, 'Chat 1', 'Delete');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Chat 1'), findsNothing);
    expect(_at(router), '/');
  });

  testWidgets('a long-press opens the menu of a row not hovered', (tester) async {
    await _host(tester, FakeChatApi(chats: _chats(1)));
    await tester.longPress(find.text('Chat 1'));
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsOneWidget);
  });
}
