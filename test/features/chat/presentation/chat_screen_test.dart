import 'dart:async';
import 'dart:convert';

import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/features/account/application/session.dart';
import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/chat/data/chat_transport.dart';
import 'package:chocomousse/features/chat/presentation/chat_screen.dart';
import 'package:chocomousse/features/chat/presentation/widgets/chat_bits.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/side_panel/presentation/side_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../account/fakes.dart';
import '../../../helpers.dart';
import '../../../itinerary/fakes.dart';
import '../fakes.dart';

Map<String, Object?> _chat() => {
  'id': 'c1',
  'title': 'Rome in April',
  'createdAt': '2026-11-09T18:40:00Z',
  'lastMessageAt': '2026-11-10T19:02:11Z',
  'expiresAt': '2027-02-08T19:02:11Z',
  'busy': false,
  'messages': [
    {'id': '0001', 'role': 'traveller', 'text': 'Hi', 'at': '2026-11-10T19:00:00Z'},
    {
      'id': '0002',
      'role': 'assistant',
      'text': 'Where would you like to go?',
      'suggestions': ['Plan 5 days in Rome'],
      'at': '2026-11-10T19:00:05Z',
    },
  ],
};

Future<FakeChatTransport> _open(
  WidgetTester tester, {
  Size size = desktop,
  ThemeMode mode = ThemeMode.light,
  List<Object> replies = const [],
}) async {
  final transport = FakeChatTransport(replies);
  await pumpApp(
    tester,
    const ChatScreen(chatId: 'c1'),
    size: size,
    mode: mode,
    overrides: [
      ...chatOverrides(transport, answers: [(200, _chat())]),
      plansProvider.overrideWith((ref) => const PlanList(items: [], count: 0, max: 50)),
      profileProvider.overrideWith((ref) => defaultProfile()),
      planRepositoryProvider.overrideWithValue(FakePlanRepository()),
    ],
  );
  await tester.pumpAndSettle();
  return transport;
}

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(find.byTooltip('Send'));
  await tester.pump();
}

void main() {
  for (final size in [phone, desktop]) {
    forBothModes('steps show one by one, then the answer and its groups in order (${size.width.toInt()})', (
      tester,
      mode,
    ) async {
      final live = StreamController<List<int>>();
      await _open(tester, size: size, mode: mode, replies: [live.stream]);
      expect(find.text('Where would you like to go?'), findsOneWidget);

      await _send(tester, 'Plan 5 days in Rome');
      expect(find.text('Plan 5 days in Rome'), findsWidgets);

      live
        ..add(utf8.encode(sse('chat', {'chatId': 'c1', 'title': null, 'messageId': '0003'})))
        ..add(utf8.encode(sse('step', stepJson())));
      await tester.pump();
      await tester.pump();
      expect(find.text('Searched flights Beirut → Rome · 23 fares'), findsOneWidget);
      expect(find.byType(WorkingIndicator), findsOneWidget);
      expect(find.text('Searched hotels in Rome · 48 found'), findsNothing);

      live.add(
        utf8.encode(
          sse(
            'step',
            stepJson(
              tool: 'search_hotels',
              summary: 'Searched hotels in Rome · 48 found',
              total: 48,
              cards: [hotelCardJson()],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Searched hotels in Rome · 48 found'), findsOneWidget);

      live.add(
        utf8.encode(
          sse(
            'final',
            finalJson(
              messageId: '0004',
              cards: [hotelCardJson(), flightCardJson(), planCardJson()],
              suggestions: ['Add a car'],
            ),
          ),
        ),
      );
      await live.close();
      await tester.pumpAndSettle();

      expect(find.byType(WorkingIndicator), findsNothing);
      expect(find.text('Here is a 5-day plan.'), findsOneWidget);
      final plan = tester.getTopLeft(find.text('PLAN')).dy;
      final flights = tester.getTopLeft(find.text('FLIGHTS')).dy;
      final hotels = tester.getTopLeft(find.text('HOTELS')).dy;
      expect(plan < flights && flights < hotels, isTrue, reason: 'plan, then flights, then hotels');
      expect(find.text('See all 48'), findsOneWidget);
      expect(find.text('See all 23'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Add a car'), findsOneWidget);
    });
  }

  testWidgets('a suggestion chip sends its text', (tester) async {
    final transport = await _open(tester);
    await tester.tap(find.widgetWithText(ActionChip, 'Plan 5 days in Rome'));
    await tester.pumpAndSettle();
    expect(transport.posts.single.path, '/assistant/chats/c1/messages');
    expect(transport.posts.single.body['text'], 'Plan 5 days in Rome');
  });

  testWidgets('a failed answer keeps its steps and Try again sends it again', (tester) async {
    final transport = await _open(
      tester,
      replies: [
        [
          sse('chat', {'chatId': 'c1', 'title': null, 'messageId': '0003'}),
          sse('step', stepJson()),
          sse('error', {'warning': 'The flight search is down.'}),
        ].join(),
      ],
    );
    await _send(tester, 'Flights to Rome');
    await tester.pumpAndSettle();
    expect(find.text('The flight search is down.'), findsOneWidget);
    expect(find.text('Searched flights Beirut → Rome · 23 fares'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(transport.posts, hasLength(2));
    expect(transport.posts.last.body['text'], 'Flights to Rome');
    expect(find.text('The flight search is down.'), findsNothing);
    expect(find.text('Here is a 5-day plan.'), findsOneWidget);
  });

  for (final (refusal, text) in [
    (const ChatRefused(409, problem: {'code': 'chat-busy'}), 'Still answering on another device…'),
    (const ChatRefused(409, problem: {'code': 'chat-full'}), 'This chat is full. Start a new chat to carry on.'),
    (const ChatRefused(404), 'This chat has expired.'),
    (const ChatRefused(429), 'Too many messages. Wait a minute and try again.'),
  ]) {
    testWidgets('a ${refusal.statusCode} ${refusal.code ?? ''} refusal says "$text"', (tester) async {
      await _open(tester, replies: [refusal]);
      await _send(tester, 'Hello');
      await tester.pumpAndSettle();
      expect(find.text(text), findsWidgets);
    });
  }

  testWidgets('a step with cards opens to show them', (tester) async {
    await pumpApp(
      tester,
      ToolStepLine(step: _step(), chatKey: 'c1'),
      size: desktop,
    );
    expect(find.text('FLIGHTS'), findsNothing);
    await tester.tap(find.text('Searched flights Beirut → Rome · 23 fares'));
    await tester.pumpAndSettle();
    expect(find.text('FLIGHTS'), findsOneWidget);
    expect(find.text('ORY → FCO'), findsOneWidget);
  });

  testWidgets('a failed step is in the warning colour, with the generic icon for an unknown tool', (tester) async {
    await pumpApp(
      tester,
      ToolStepLine(
        step: _step(ok: false, tool: 'something_new'),
        chatKey: 'c1',
      ),
    );
    final summary = tester.widget<Text>(find.text('Searched flights Beirut → Rome · 23 fares'));
    expect(summary.style?.color, AppPalette.light.statusWarning);
    expect(toolIcon('something_new'), AppIcons.sparkles);
    expect(toolIcon('search_hotels'), isNot(toolIcon('search_flights')));
  });

  testWidgets('Open plan opens the Plan pane beside the chat', (tester) async {
    await _open(tester, replies: [answerSse(steps: const [])]);
    await _send(tester, 'Plan Rome');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open plan'));
    await tester.pumpAndSettle();
    expect(find.byType(SidePanel), findsOneWidget);
    expect(find.text('Mark as planned'), findsOneWidget);
  });
}

ToolStep _step({bool ok = true, String tool = 'search_flights'}) => ToolStep.fromJson(stepJson(ok: ok, tool: tool));
