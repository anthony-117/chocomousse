import 'dart:async';

import 'package:chocomousse/app/theme/app_theme.dart';
import 'package:chocomousse/features/assistant/application/chat_controller.dart';
import 'package:chocomousse/features/assistant/data/assistant_models.dart';
import 'package:chocomousse/features/assistant/data/assistant_repository.dart';
import 'package:chocomousse/features/assistant/presentation/assistant_screen.dart';
import 'package:chocomousse/features/assistant/presentation/widgets/action_card.dart';
import 'package:chocomousse/features/assistant/presentation/widgets/chat_bubble.dart';
import 'package:chocomousse/features/assistant/presentation/widgets/suggestion_chips.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'fakes.dart';

void main() {
  late FakeAssistantRepository api;
  late ProviderContainer container;

  Future<void> show(WidgetTester tester, {bool wide = false, ChatCity? city}) async {
    if (wide) {
      tester.view
        ..physicalSize = const Size(1440, 1000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    } else {
      usePhoneSize(tester, height: 900);
    }
    container = ProviderContainer(overrides: [assistantRepositoryProvider.overrideWithValue(api)]);
    addTearDown(container.dispose);
    if (city != null) container.read(chatControllerProvider.notifier).startFor(city);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: AssistantScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
  }

  setUp(() => api = FakeAssistantRepository());

  testWidgets('an empty chat greets, shows the Gemini notice and suggestions, and has no New chat', (tester) async {
    await show(tester);

    expect(find.text('Assistant'), findsOneWidget);
    expect(find.text('Ask about any city'), findsOneWidget);
    expect(find.textContaining('Ask me about any city'), findsOneWidget);
    expect(find.text(AssistantScreen.privacyNotice), findsOneWidget);
    for (final question in SuggestionChips.forCity(null)) {
      expect(find.text(question), findsOneWidget);
    }
    expect(find.byTooltip('New chat'), findsNothing);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send_rounded)).onPressed, isNull);
  });

  testWidgets('a chat about a city says so in the header and suggests questions about it', (tester) async {
    await show(tester, city: (id: '3169070', name: 'Rome'));

    expect(find.textContaining('About Rome · '), findsOneWidget);
    expect(find.textContaining('your trip to Rome'), findsOneWidget);
    expect(find.text('Do I need a visa?'), findsOneWidget);
    expect(find.byTooltip('New chat'), findsOneWidget);
  });

  testWidgets('tapping a suggestion sends it', (tester) async {
    await show(tester);

    await tester.ensureVisible(find.text('Weather in Rome next week'));
    await tester.tap(find.text('Weather in Rome next week'));
    await tester.pumpAndSettle();

    expect(api.requests.single.messages.single.text, 'Weather in Rome next week');
    expect(find.text('Here you go.'), findsOneWidget);
  });

  testWidgets('while waiting: the message shows, the input is off, the typing bubble shows', (tester) async {
    final answer = Completer<AssistantReply>();
    api.pending = answer;
    await show(tester);

    await tester.enterText(find.byType(TextField), 'Hotels in Rome?');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    expect(find.widgetWithText(ChatBubble, 'Hotels in Rome?'), findsOneWidget);
    expect(find.byType(TypingBubble), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(find.byType(SuggestionChips), findsNothing);

    answer.complete(reply('Two hotels.'));
    await tester.pumpAndSettle();
    expect(find.byType(TypingBubble), findsNothing);
    expect(find.text('Two hotels.'), findsOneWidget);
  });

  testWidgets('an answer shows its cards and the sources that had no data', (tester) async {
    api.answerWith(
      reply(
        'Hotel Artemide: 612 USD for the stay.',
        cards: [cardJson()],
        warnings: ['Events is unavailable right now.'],
      ),
    );
    await show(tester);

    await type(tester, 'Hotels?');

    expect(find.byType(ActionCard), findsOneWidget);
    expect(find.text('HOTELS'), findsOneWidget);
    expect(find.text('Hotels in Rome'), findsOneWidget);
    expect(find.text('10 – 15 Apr · 2 adults'), findsOneWidget);
    expect(find.text('Events is unavailable right now.'), findsOneWidget);
  });

  testWidgets('a failed request keeps the chat, says why, and Try again resends', (tester) async {
    api
      ..answerWith(DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError))
      ..answerWith(reply('Back online.'));
    await show(tester);

    await type(tester, 'Visa?');

    expect(find.text('Visa?'), findsOneWidget);
    expect(find.text('Not sent. Cannot reach the TravelGenie server.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Not sent'), findsNothing);
    expect(find.text('Back online.'), findsOneWidget);
    expect(api.requests, hasLength(2));
  });

  testWidgets('too many messages says to wait, and Try again resends', (tester) async {
    final options = RequestOptions(path: '/assistant/messages');
    api
      ..answerWith(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<void>(requestOptions: options, statusCode: 429),
        ),
      )
      ..answerWith(reply('You need a visa.'));
    await show(tester);

    await type(tester, 'Visa?');

    expect(find.text('Not sent. Too many messages. Wait a minute and try again.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('You need a visa.'), findsOneWidget);
  });

  testWidgets('only the latest unsent message shows the error and Try again', (tester) async {
    api
      ..answerWith(DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError))
      ..answerWith(DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError));
    await show(tester);

    await type(tester, 'Visa?');
    await type(tester, 'Weather?');

    expect(find.text('Not sent.'), findsOneWidget);
    expect(find.text('Not sent. Cannot reach the TravelGenie server.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a busy assistant shows its warning as the answer, with Try again', (tester) async {
    api.answerWith(reply('', warnings: ['The assistant is busy right now. Try again in a minute.']));
    await show(tester);

    await type(tester, 'Visa?');

    expect(find.byType(WarningBubble), findsOneWidget);
    expect(find.text('The assistant is busy right now. Try again in a minute.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byType(WarningBubble), findsNothing);
    expect(find.text('Here you go.'), findsOneWidget);
  });

  testWidgets('New chat clears the conversation', (tester) async {
    await show(tester);
    await type(tester, 'Hi');
    expect(find.text('Here you go.'), findsOneWidget);

    await tester.tap(find.byTooltip('New chat'));
    await tester.pumpAndSettle();

    expect(find.text('Here you go.'), findsNothing);
    expect(find.text(AssistantScreen.privacyNotice), findsOneWidget);
  });

  testWidgets('on a wide screen the chat column works the same', (tester) async {
    api.answerWith(reply('Two hotels.', cards: [cardJson()]));
    await show(tester, wide: true);

    await type(tester, 'Hotels?');

    expect(find.text('Two hotels.'), findsOneWidget);
    expect(find.byType(ActionCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long conversation scrolls without overflowing on a phone', (tester) async {
    api.fallback = reply('A long answer. ' * 30, cards: [cardJson()]);
    await show(tester);

    for (var i = 0; i < 4; i++) {
      await type(tester, 'Question $i');
    }

    expect(tester.takeException(), isNull);
    // The newest answer is in view: the list sits at its end.
    final list = tester.state<ScrollableState>(
      find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first,
    );
    expect(list.position.pixels, list.position.maxScrollExtent);
    expect(list.position.maxScrollExtent, greaterThan(0));
  });
}
