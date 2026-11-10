import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/app/router.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/shell/recents_list.dart';
import 'package:chocomousse/features/shell/search_chats_dialog.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../account/fakes.dart';
import '../features/chat/fakes.dart';
import '../itinerary/fakes.dart';

void main() {
  testWidgets('Recents → open → continue → Search "jazz" → open → rename → delete', (tester) async {
    tester.view
      ..physicalSize = const Size(1440, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeChatApi(
      chats: [
        chatJson(),
        chatJson(
          id: 'c2',
          title: 'Lisbon weekend',
          messages: [
            {'id': '0001', 'role': 'traveller', 'text': 'Any jazz bars in Lisbon?', 'at': '2026-11-10T19:00:00Z'},
            {
              'id': '0002',
              'role': 'assistant',
              'text': 'Two good ones.',
              'steps': <Object>[],
              'cards': [eventCardJson()],
              'at': '2026-11-10T19:02:11Z',
            },
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...signedIn(),
          ...chatApiOverrides(api),
          planRepositoryProvider.overrideWithValue(FakePlanRepository()),
          pingProvider.overrideWith(
            (ref) async =>
                PingInfo(name: 'pamplemousse', version: '1.0.0', environment: 'Test', utcNow: DateTime.utc(2026)),
          ),
        ],
        child: const TravelGenieApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = ProviderScope.containerOf(tester.element(find.byType(TravelGenieApp))).read(routerProvider);
    String at() => router.routerDelegate.currentConfiguration.uri.path;
    final recents = find.byType(RecentsList);
    Finder inRecents(String text) => find.descendant(of: recents, matching: find.text(text));

    expect(inRecents('Rome in April'), findsOneWidget);
    expect(inRecents('Lisbon weekend'), findsOneWidget);

    await tester.tap(inRecents('Rome in April'));
    await tester.pumpAndSettle();
    expect(at(), '/chat/c1');
    expect(find.text('Plan Rome'), findsOneWidget);
    expect(find.text('PLAN'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Make it 4 days');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(api.transport.posts.single.path, '/assistant/chats/c1/messages');
    expect(find.text('Make it 4 days'), findsOneWidget);
    expect(find.text('Here is a 5-day plan.'), findsNWidgets(2), reason: 'the answer appends');

    await tester.tap(find.bySemanticsLabel('Search chats'));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(SearchChatsView), matching: find.byType(TextField)), 'jazz');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(SearchChatsView), matching: find.text('Lisbon weekend')));
    await tester.pumpAndSettle();
    expect(at(), '/chat/c2');
    expect(find.text('Any jazz bars in Lisbon?'), findsOneWidget);
    expect(find.text('EVENTS'), findsOneWidget);

    await tester.tap(find.byTooltip('More for Lisbon weekend'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Lisbon jazz');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(inRecents('Lisbon jazz'), findsOneWidget);

    await tester.tap(find.byTooltip('More for Lisbon jazz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(inRecents('Lisbon jazz'), findsNothing);
    expect(inRecents('Rome in April'), findsOneWidget);
    expect(at(), AppPaths.home, reason: 'the open chat was deleted');
  });
}
