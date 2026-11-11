import 'dart:async';
import 'dart:convert';

import 'package:chocomousse/core/network/auth_interceptor.dart';
import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/chat/data/chat_events.dart';
import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/chat/data/chat_repository.dart';
import 'package:chocomousse/features/chat/data/chat_transport.dart';
import 'package:chocomousse/features/chat/data/chat_transport_io.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../itinerary/fakes.dart';
import '../fakes.dart';

final Map<String, Object?> _item = {
  'id': 'c1',
  'title': 'Rome',
  'createdAt': '2026-11-09T18:40:00Z',
  'lastMessageAt': '2026-11-10T19:02:11Z',
  'messageCount': 2,
};

final Map<String, Object?> _chat = {
  ..._item,
  'expiresAt': '2027-02-08T19:02:11Z',
  'busy': false,
  'messages': <Object>[],
};

({ChatRepository repo, ScriptedAdapter http, FakeChatTransport transport}) _setUp({
  List<(int, Object?)> answers = const [],
  List<Object> replies = const [],
  Duration watchdog = const Duration(seconds: 30),
}) {
  final http = ScriptedAdapter([...answers]);
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))..httpClientAdapter = http;
  final transport = FakeChatTransport(replies);
  return (repo: ChatRepository(dio, transport, watchdog: watchdog), http: http, transport: transport);
}

void main() {
  group('routes', () {
    test('list sends limit and before', () async {
      final s = _setUp(
        answers: [
          (
            200,
            {
              'items': [_item],
              'next': null,
              'keepDays': 90,
            },
          ),
        ],
      );
      final page = await s.repo.list(before: 'cur', limit: 10);
      expect(s.http.requests.single.path, '/assistant/chats');
      expect(s.http.requests.single.queryParameters, {'limit': 10, 'before': 'cur'});
      expect(page.items.single.title, 'Rome');
    });

    test('get, rename and delete use the chat id', () async {
      final s = _setUp(answers: [(200, _chat), (200, _item), (204, null)]);
      await s.repo.get('c1');
      await s.repo.rename('c1', '  Rome with Maya ');
      await s.repo.delete('c1');
      expect(s.http.requests.map((r) => '${r.method} ${r.path}'), [
        'GET /assistant/chats/c1',
        'PATCH /assistant/chats/c1',
        'DELETE /assistant/chats/c1',
      ]);
      expect(s.http.requests[1].data, {'title': 'Rome with Maya'});
    });

    test('rename refuses an empty or long title without calling the API', () async {
      final s = _setUp();
      await expectLater(s.repo.rename('c1', '  '), throwsA(isA<FieldError>()));
      await expectLater(s.repo.rename('c1', 'a' * 41), throwsA(isA<FieldError>()));
      expect(s.http.requests, isEmpty);
    });

    test('search sends q, and skips a q under 2 characters', () async {
      final s = _setUp(
        answers: [
          (
            200,
            {
              'chats': [_item],
              'plans': [summaryJson()],
            },
          ),
        ],
      );
      expect((await s.repo.search('j')).isEmpty, isTrue);
      final result = await s.repo.search(' jazz ');
      expect(s.http.requests.single.path, '/assistant/chats/search');
      expect(s.http.requests.single.queryParameters, {'q': 'jazz'});
      expect(result.plans.single.id, 'p1');
    });

    test('a 404 is ChatNotFound and a 400 names the field', () async {
      final s = _setUp(
        answers: [
          (404, problem(404, 'not-found')),
          (
            400,
            {
              'status': 400,
              'errors': {
                'title': ['Too long.'],
              },
            },
          ),
        ],
      );
      await expectLater(s.repo.get('gone'), throwsA(isA<ChatNotFound>()));
      await expectLater(
        s.repo.rename('c1', 'Rome'),
        throwsA(isA<FieldError>().having((e) => e.field, 'field', 'title')),
      );
    });

    test('send posts a new chat, then the next message to the chat', () async {
      final s = _setUp(replies: [answerSse(), answerSse()]);
      await s.repo.send(request: ChatRequest(text: 'Plan Rome')).toList();
      await s.repo
          .send(
            chatId: 'c1',
            request: ChatRequest(text: 'Add a car'),
          )
          .toList();
      expect(s.transport.posts.map((p) => p.path), ['/assistant/chats', '/assistant/chats/c1/messages']);
      expect(s.transport.posts.first.body, {'text': 'Plan Rome'});
    });
  });

  group('stream', () {
    test('gives chat, the steps, then final', () async {
      final s = _setUp(
        replies: [
          answerSse(
            steps: [
              stepJson(),
              stepJson(tool: 'search_hotels', cards: [hotelCardJson()]),
            ],
            last: finalJson(planChanged: 'p1'),
          ),
        ],
      );
      final events = await s.repo.send(request: ChatRequest(text: 'Plan Rome')).toList();
      expect(events.map((e) => e.runtimeType), [ChatStarted, StepDone, StepDone, AnswerDone]);
      expect((events.first as ChatStarted).chatId, 'c1');
      expect((events[2] as StepDone).step.cards.single, isA<HotelCard>());
      final done = events.last as AnswerDone;
      expect(done.title, 'Rome in April for two');
      expect(done.message.planChanged, 'p1');
    });

    test('an error event ends the stream with its warning', () async {
      final text = [
        sse('chat', {'chatId': 'c1', 'messageId': '0001'}),
        sse('step', stepJson()),
        sse('error', {'warning': 'The assistant is busy right now. Try again in a minute.'}),
      ].join();
      final events = await _setUp(replies: [text]).repo.send(request: ChatRequest(text: 'Hi')).toList();
      expect(events.map((e) => e.runtimeType), [ChatStarted, StepDone, AnswerFailed]);
      expect((events.last as AnswerFailed).warning, 'The assistant is busy right now. Try again in a minute.');
    });

    test('a stream ending without final is a lost answer', () async {
      final text = sse('chat', {'chatId': 'c1', 'messageId': '0001'}) + sse('step', stepJson());
      final events = await _setUp(replies: [text]).repo.send(request: ChatRequest(text: 'Hi')).toList();
      expect(events.last, isA<AnswerFailed>().having((e) => e.warning, 'warning', AnswerFailed.lost));
    });

    test('unknown events are skipped', () async {
      final text =
          sse('chat', {'chatId': 'c1', 'messageId': '0001'}) + sse('progress', {'x': 1}) + sse('final', finalJson());
      final events = await _setUp(replies: [text]).repo.send(request: ChatRequest(text: 'Hi')).toList();
      expect(events.map((e) => e.runtimeType), [ChatStarted, AnswerDone]);
    });

    test('the watchdog ends a silent stream as a lost answer', () async {
      final bytes = StreamController<List<int>>();
      final repo = _setUp(replies: [bytes.stream], watchdog: const Duration(milliseconds: 80)).repo;
      final events = <ChatEvent>[];
      final done = repo.send(request: ChatRequest(text: 'Hi')).listen(events.add).asFuture<void>();
      await Future<void>.delayed(Duration.zero);
      bytes.add(utf8.encode(sse('chat', {'chatId': 'c1', 'messageId': '0001'})));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      bytes.add(utf8.encode(': ping\n\n'));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(events.single, isA<ChatStarted>(), reason: 'a ping keeps the answer alive');
      await done;
      expect(events.last, isA<AnswerFailed>().having((e) => e.warning, 'warning', AnswerFailed.lost));
      expect(bytes.hasListener, isFalse);
    });

    test('the production watchdog is 30 s', () {
      expect(_setUp().repo.watchdog, const Duration(seconds: 30));
    });
  });

  group('refusals', () {
    Future<Object?> refusal(ChatRefused refused) async {
      try {
        await _setUp(replies: [refused]).repo.send(request: ChatRequest(text: 'Hi')).toList();
        return null;
      } on ChatFailure catch (e) {
        return e;
      }
    }

    test('maps each refusal', () async {
      expect(await refusal(const ChatRefused(409, problem: {'code': 'chat-busy'})), isA<ChatBusy>());
      expect(
        await refusal(const ChatRefused(409, problem: {'code': 'chat-full', 'detail': 'This chat is full.'})),
        isA<ChatFull>().having((e) => e.message, 'message', 'This chat is full.'),
      );
      expect(await refusal(const ChatRefused(404)), isA<ChatNotFound>());
      expect(
        await refusal(const ChatRefused(429, retryAfter: Duration(seconds: 42))),
        isA<TooManyMessages>().having((e) => e.retryAfter, 'retryAfter', const Duration(seconds: 42)),
      );
      expect(
        await refusal(
          const ChatRefused(
            400,
            problem: {
              'errors': {
                'trip.tripBudget': ['Must be above 0.'],
              },
            },
          ),
        ),
        isA<FieldError>().having((e) => e.field, 'field', 'trip.tripBudget'),
      );
      expect(await refusal(const ChatRefused(503)), isA<ChatUnavailable>());
    });
  });

  group('DioChatTransport', () {
    test('streams a 200 event-stream answer', () async {
      final adapter = _SseAdapter([(200, 'text/event-stream', answerSse())]);
      final transport = DioChatTransport(_dio(adapter), const NoApiSession());
      final bytes = await transport.post('/assistant/chats', {'text': 'Hi'});
      expect(await utf8.decodeStream(bytes), answerSse());
      expect(adapter.requests.single.headers['Accept'], 'text/event-stream');
    });

    test('renews the sign-in once on a 401 and retries', () async {
      final adapter = _SseAdapter([
        (401, 'application/problem+json', jsonEncode(problem(401, 'sign-in-required'))),
        (200, 'text/event-stream', answerSse()),
      ]);
      final session = _Session();
      final bytes = await DioChatTransport(_dio(adapter), session).post('/assistant/chats', {'text': 'Hi'});
      await bytes.drain<void>();
      expect(session.refreshed, 1);
      expect(adapter.requests, hasLength(2));
    });

    test('a refusal carries its problem and Retry-After', () async {
      final adapter = _SseAdapter([(429, 'application/problem+json', '{"status":429}')], retryAfter: '30');
      final transport = DioChatTransport(_dio(adapter), const NoApiSession());
      await expectLater(
        transport.post('/assistant/chats', {'text': 'Hi'}),
        throwsA(
          isA<ChatRefused>()
              .having((e) => e.statusCode, 'status', 429)
              .having((e) => e.retryAfter, 'retryAfter', const Duration(seconds: 30)),
        ),
      );
    });
  });
}

Dio _dio(HttpClientAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))..httpClientAdapter = adapter;

class _SseAdapter implements HttpClientAdapter {
  _SseAdapter(this.answers, {this.retryAfter});

  final List<(int, String, String)> answers;
  final String? retryAfter;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, type, body) = answers.removeAt(0);
    return ResponseBody(
      Stream.value(utf8.encode(body)),
      status,
      headers: {
        Headers.contentTypeHeader: [type],
        'retry-after': ?(retryAfter == null ? null : [retryAfter!]),
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Session implements ApiSession {
  int refreshed = 0;

  @override
  Future<String?> token({bool refresh = false}) async {
    if (refresh) refreshed++;
    return 'token-$refreshed';
  }

  @override
  Future<void> signInRejected() async {}

  @override
  Future<void> emailNotConfirmed() async {}
}
