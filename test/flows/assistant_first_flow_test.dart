import 'dart:async';
import 'dart:convert';

import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/app/router.dart';
import 'package:chocomousse/features/chat/presentation/widgets/chat_bits.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/side_panel/presentation/side_panel.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../account/fakes.dart';
import '../features/chat/fakes.dart';
import '../helpers.dart';
import '../itinerary/fakes.dart';

const _steps = [
  ('search_flights', 'Searched flights Beirut → Rome · 23 fares'),
  ('search_hotels', 'Searched hotels in Rome · 48 found, ranked for you'),
  ('build_plan', 'Built your plan · 91 % match'),
];

void main() {
  for (final (name, size) in [('desktop', desktop), ('phone', phone)]) {
    testWidgets('$name: one message builds a plan; the steps come first, then the cards, then the Plan pane', (
      tester,
    ) async {
      tester.view
        ..physicalSize = Size(size.width, 1400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final live = StreamController<List<int>>();
      final transport = FakeChatTransport([live.stream]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...signedIn(),
            ...chatOverrides(transport),
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
      expect(at(), AppPaths.home);
      expect(find.text('Where to next, Sam?'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Plan 5 days in Rome for two in April');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();

      live.add(utf8.encode(sse('chat', {'chatId': 'c9', 'title': 'Rome in April', 'messageId': '0001'})));
      // The working spinner turns until the answer, so wait a fixed time, not for the screen to settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(at(), '/chat/c9');
      expect(find.text('Plan 5 days in Rome for two in April'), findsOneWidget);

      for (final (i, (tool, summary)) in _steps.indexed) {
        live.add(
          utf8.encode(
            sse(
              'step',
              stepJson(
                tool: tool,
                summary: summary,
                cards: switch (tool) {
                  'search_hotels' => [hotelCardJson()],
                  'build_plan' => [planCardJson()],
                  _ => null,
                },
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text(summary), findsOneWidget, reason: 'step ${i + 1}');
        if (i + 1 < _steps.length) expect(find.text(_steps[i + 1].$2), findsNothing);
        expect(find.byType(WorkingIndicator), findsOneWidget);
        expect(find.text('Here is a 5-day plan.'), findsNothing, reason: 'the answer comes after the steps');
      }

      live.add(utf8.encode(sse('final', finalJson(cards: [planCardJson(), flightCardJson(), hotelCardJson()]))));
      await live.close();
      await tester.pumpAndSettle();
      expect(find.text('Here is a 5-day plan.'), findsOneWidget);
      expect(find.text('PLAN'), findsOneWidget);
      expect(find.text('FLIGHTS'), findsOneWidget);
      expect(find.text('HOTELS'), findsOneWidget);
      expect(transport.posts.single.path, '/assistant/chats');

      await tester.tap(find.text('Open plan'));
      await tester.pumpAndSettle();
      expect(find.byType(SidePanel), findsOneWidget);
      expect(find.text('Mark as planned'), findsOneWidget);
      if (size == phone) {
        expect(find.byType(BottomSheet), findsOneWidget, reason: 'the panel is a sheet on phones');
      } else {
        expect(find.byType(BottomSheet), findsNothing, reason: 'the panel sits beside the chat');
      }
      expect(at(), '/chat/c9');
    });
  }
}
