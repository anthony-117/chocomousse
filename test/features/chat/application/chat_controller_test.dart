import 'dart:async';
import 'dart:convert';

import 'package:chocomousse/features/account/application/session.dart';
import 'package:chocomousse/features/chat/application/chat_controller.dart';
import 'package:chocomousse/features/chat/application/recents.dart';
import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/chat/data/chat_repository.dart';
import 'package:chocomousse/features/chat/data/chat_transport.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../account/fakes.dart';
import '../../../itinerary/fakes.dart';
import '../fakes.dart';

Map<String, Object?> chatJson({bool busy = false, List<Map<String, Object?>>? messages}) => {
  'id': 'c1',
  'title': 'Rome',
  'createdAt': '2026-11-09T18:40:00Z',
  'lastMessageAt': '2026-11-10T19:02:11Z',
  'expiresAt': '2027-02-08T19:02:11Z',
  'busy': busy,
  'messages':
      messages ??
      [
        {'id': '0001', 'role': 'traveller', 'text': 'Plan Rome', 'at': '2026-11-10T19:00:00Z'},
        {'id': '0002', 'role': 'assistant', 'text': 'Here.', 'at': '2026-11-10T19:02:11Z'},
      ],
};

class _Harness {
  _Harness({List<Object> replies = const [], List<(int, Object?)> answers = const []})
    : transport = FakeChatTransport(replies),
      http = ScriptedAdapter([...answers]),
      plans = FakePlanRepository() {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))..httpClientAdapter = http;
    container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(ChatRepository(dio, transport)),
        recentsProvider.overrideWith(_CountingRecents.new),
        plansProvider.overrideWith((ref) => const PlanList(items: [], count: 0, max: 50)),
        profileProvider.overrideWith((ref) => defaultProfile()),
        planRepositoryProvider.overrideWithValue(plans),
      ],
    );
    addTearDown(container.dispose);
  }

  final FakeChatTransport transport;
  final ScriptedAdapter http;
  final FakePlanRepository plans;
  late final ProviderContainer container;

  ChatController controller([String? key]) => container.read(chatProvider(key).notifier);

  ChatState state([String? key]) => container.read(chatProvider(key));
}

int _recentsBuilds = 0;

class _CountingRecents extends RecentsController {
  @override
  Future<RecentsState> build() async {
    _recentsBuilds++;
    return const RecentsState(items: [], keepDays: 90);
  }
}

/// Waits until [done] holds, for at most a second of real time (dio answers over several event-loop turns).
Future<void> until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Moves the test clock by [by], then lets the fake API's answers through.
Future<void> _settle(WidgetTester tester, [Duration by = Duration.zero]) async {
  await tester.pump(by);
  for (var i = 0; i < 10; i++) {
    await tester.pump();
  }
}

void main() {
  setUp(() {
    _recentsBuilds = 0;
  });

  group('send in a new chat', () {
    test('moves the answer to the new chat id and calls back', () async {
      final h = _Harness();
      final created = <String>[];
      h.controller().onChatCreated = created.add;
      h.container.listen(recentsProvider, (_, _) {});
      await h.controller().send('Plan Rome');

      expect(created, ['c1']);
      expect(h.state().isEmpty, isTrue, reason: 'the home starts a fresh chat');
      final chat = h.state('c1');
      expect(chat.chatId, 'c1');
      expect(chat.title, 'Rome in April for two');
      expect(chat.status, ChatStatus.idle);
      expect(chat.messages.map((m) => m.role), [ChatRole.traveller, ChatRole.assistant]);
      expect(chat.messages.first.id, '0001', reason: 'the stored id replaces the local one');
      expect(h.http.requests, isEmpty, reason: 'the adopted chat is not loaded again');
      expect(h.transport.posts.single.path, '/assistant/chats');
    });

    test('shows the traveller message and the steps while answering', () async {
      final bytes = StreamController<List<int>>();
      final h = _Harness(replies: [bytes.stream]);
      final sending = h.controller().send('Plan Rome');
      await Future<void>.delayed(Duration.zero);
      expect(h.state().messages.single.text, 'Plan Rome');
      expect(h.state().isSending, isTrue);

      bytes
        ..add(utf8.encode(sse('chat', {'chatId': 'c1', 'messageId': '0001'})))
        ..add(utf8.encode(sse('step', stepJson())))
        ..add(utf8.encode(sse('step', stepJson(tool: 'search_hotels', summary: 'Searched hotels'))));
      await Future<void>.delayed(Duration.zero);
      expect(h.state('c1').pending!.steps.map((s) => s.summary), [
        'Searched flights Beirut → Rome · 23 fares',
        'Searched hotels',
      ]);

      bytes.add(utf8.encode(sse('final', finalJson(cards: []))));
      await bytes.close();
      await sending;
      final answer = h.state('c1').messages.last;
      expect(answer.steps, hasLength(2), reason: 'the steps stay with the answer');
      expect(h.state('c1').pending, isNull);
    });
  });

  test('a message in an existing chat goes to that chat', () async {
    final h = _Harness(answers: [(200, chatJson())], replies: [answerSse()]);
    final controller = h.controller('c1');
    await until(() => h.state('c1').status == ChatStatus.idle);
    expect(h.state('c1').messages, hasLength(2));
    await controller.send('Add a car');
    expect(h.transport.posts.single.path, '/assistant/chats/c1/messages');
    expect(h.state('c1').messages, hasLength(4));
  });

  test('a changed plan and Recents are reloaded', () async {
    final h = _Harness(
      replies: [answerSse(last: finalJson(planChanged: 'p1'))],
    );
    h.container
      ..listen(recentsProvider, (_, _) {})
      ..listen(planProvider('p1'), (_, _) {});
    await h.container.read(recentsProvider.future);
    await h.container.read(planProvider('p1').future);
    await h.controller().send('Make day 2 relaxed');
    await h.container.read(recentsProvider.future);
    await h.container.read(planProvider('p1').future);
    expect(h.plans.calls.where((c) => c == 'plan p1'), hasLength(2));
    expect(_recentsBuilds, greaterThanOrEqualTo(2));
  });

  test('an error keeps the steps and marks the message not sent; Try again sends it anew', () async {
    final failing = [
      sse('chat', {'chatId': 'c1', 'messageId': '0001'}),
      sse('step', stepJson()),
      sse('error', {'warning': 'The assistant is busy right now.'}),
    ].join();
    final h = _Harness(replies: [failing, answerSse()]);
    await h.controller().send('Plan Rome');
    final failed = h.state('c1');
    expect(failed.status, ChatStatus.failed);
    expect(failed.failure!.message, 'The assistant is busy right now.');
    expect(failed.messages.single.notSent, isTrue);
    expect(failed.pending!.steps, hasLength(1));
    expect(failed.canRetry, isTrue);

    await h.controller('c1').retry();
    final again = h.state('c1');
    expect(again.status, ChatStatus.idle);
    expect(again.messages.map((m) => (m.text, m.notSent)), [('Plan Rome', false), ('Here is a 5-day plan.', false)]);
    expect(h.transport.posts.map((p) => p.path), ['/assistant/chats', '/assistant/chats/c1/messages']);
  });

  group('refusals', () {
    Future<ChatState> refused(ChatRefused refusal) async {
      final h = _Harness(replies: [refusal]);
      await h.controller().send('Plan Rome');
      return h.state();
    }

    test('each refusal fails the message with its failure', () async {
      final cases = {
        const ChatRefused(409, problem: {'code': 'chat-busy'}): isA<ChatBusy>(),
        const ChatRefused(409, problem: {'code': 'chat-full'}): isA<ChatFull>(),
        const ChatRefused(404): isA<ChatNotFound>(),
        const ChatRefused(429, retryAfter: Duration(seconds: 5)): isA<TooManyMessages>(),
        const ChatRefused(
          400,
          problem: {
            'errors': {
              'text': ['Too long.'],
            },
          },
        ): isA<FieldError>(),
      };
      for (final MapEntry(key: refusal, value: matcher) in cases.entries) {
        final state = await refused(refusal);
        expect(state.status, ChatStatus.failed);
        expect(state.failure, matcher);
        expect(state.messages.single.notSent, isTrue);
      }
    });
  });

  test('sends nothing while an answer is running, or for empty text', () async {
    final bytes = StreamController<List<int>>();
    final h = _Harness(replies: [bytes.stream]);
    unawaited(h.controller().send('Plan Rome'));
    await Future<void>.delayed(Duration.zero);
    await h.controller().send('Again');
    await h.controller().send('   ');
    expect(h.transport.posts, hasLength(1));
    await bytes.close();
  });

  group('load', () {
    test('reads the chat', () async {
      final h = _Harness(answers: [(200, chatJson())]);
      expect(h.state('c1').status, ChatStatus.loading);
      await until(() => h.state('c1').status != ChatStatus.loading);
      expect(h.state('c1').title, 'Rome');
      expect(h.state('c1').messages, hasLength(2));
      expect(h.state('c1').status, ChatStatus.idle);
    });

    test('a missing chat fails with ChatNotFound', () async {
      final h = _Harness(answers: [(404, problem(404, 'not-found'))])..state('gone');
      await until(() => h.state('gone').status != ChatStatus.loading);
      expect(h.state('gone').failure, isA<ChatNotFound>());
    });

    testWidgets('a busy chat is checked every 5 s until it is done', (tester) async {
      final h = _Harness(answers: [(200, chatJson(busy: true)), (200, chatJson(busy: true)), (200, chatJson())])
        ..state('c1');
      await _settle(tester);
      expect(h.state('c1').status, ChatStatus.busyElsewhere);
      await _settle(tester, const Duration(seconds: 5));
      expect(h.state('c1').status, ChatStatus.busyElsewhere);
      await _settle(tester, const Duration(seconds: 5));
      expect(h.state('c1').status, ChatStatus.idle);
      expect(h.http.requests, hasLength(3));
    });

    testWidgets('a chat busy for longer than 60 s is no longer checked', (tester) async {
      final h = _Harness(answers: [for (var i = 0; i < 20; i++) (200, chatJson(busy: true))])..state('c1');
      await _settle(tester);
      for (var i = 0; i < 20; i++) {
        await _settle(tester, const Duration(seconds: 5));
      }
      expect(h.http.requests, hasLength(1 + 12), reason: 'the load, then one check every 5 s for 60 s');
      expect(h.state('c1').status, ChatStatus.busyElsewhere);
    });
  });
}
