import 'dart:convert';

import 'package:chocomousse/features/assistant/data/assistant_models.dart';
import 'package:chocomousse/features/assistant/data/assistant_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// Answers with [body] and records the request.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.body);

  final Map<String, Object?> body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final _context = ChatContext(
  destinationId: '3169070',
  from: DateTime(2027, 4, 10),
  to: DateTime(2027, 4, 15),
  adults: 2,
  passport: 'LB',
  currency: 'USD',
);

ChatMessage _traveller(String text) => ChatMessage(role: ChatRole.traveller, text: text);

void main() {
  group('models', () {
    test('a reply reads its text, cards and warnings', () {
      final parsed = AssistantReply.fromJson({
        'text': 'Two hotels.',
        'cards': [
          cardJson(),
          cardJson(
            kind: 'places',
            title: 'Restaurants in Rome',
            from: null,
            to: null,
            adults: null,
            category: 'restaurant',
          ),
          cardJson(kind: 'flights', originId: '2988507'),
          cardJson(kind: 'overview', title: 'About Rome'),
        ],
        'warnings': ['Events is unavailable right now.'],
      });

      expect(parsed.text, 'Two hotels.');
      expect(parsed.warnings, ['Events is unavailable right now.']);
      final [hotels, places, flights, overview] = parsed.cards;
      expect(
        (hotels.kind, hotels.from, hotels.to, hotels.adults),
        (AssistantCardKind.hotels, DateTime(2027, 4, 10), DateTime(2027, 4, 15), 2),
      );
      expect(hotels.route, '/discover/destination/3169070/hotels');
      expect(
        (places.route, places.label, places.from),
        ('/discover/destination/3169070/places?category=restaurant', 'RESTAURANTS', null),
      );
      expect((flights.route, flights.originId), ('/discover/destination/3169070/flights', '2988507'));
      expect((overview.route, overview.label), ('/discover/destination/3169070', 'CITY GUIDE'));
    });

    test('a card of an unknown kind is skipped, and missing lists are empty', () {
      final parsed = AssistantReply.fromJson({
        'text': '',
        'cards': [cardJson(kind: 'cars')],
      });

      expect(parsed.cards, isEmpty);
      expect(parsed.warnings, isEmpty);
    });

    test('an answer with no text is a warning-only message', () {
      const warning = ChatMessage(role: ChatRole.assistant, text: '', warnings: ['Busy']);

      expect(warning.isWarningOnly, isTrue);
      expect(_traveller('').isWarningOnly, isFalse);
    });

    test('the context leaves out what is not set', () {
      final json = ChatContext(
        from: DateTime(2027, 1, 5),
        to: DateTime(2027, 1, 9),
        adults: 1,
        passport: 'FR',
        currency: 'EUR',
      ).toJson();

      expect(json, {'from': '2027-01-05', 'to': '2027-01-09', 'adults': 1, 'passport': 'FR', 'currency': 'EUR'});
    });
  });

  group('repository', () {
    test('posts the conversation and the trip, and reads the reply', () async {
      final adapter = _Adapter({
        'text': 'You need a visa.',
        'cards': [cardJson(kind: 'overview')],
        'warnings': <String>[],
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = adapter;

      final result = await AssistantRepository(dio).ask([
        _traveller('Visa?'),
        const ChatMessage(role: ChatRole.assistant, text: '', warnings: ['Busy']),
        _traveller('Visa, please?'),
      ], _context);

      expect(result.text, 'You need a visa.');
      expect(result.cards.single.kind, AssistantCardKind.overview);
      final sent = adapter.last!;
      expect((sent.method, sent.path), ('POST', '/assistant/messages'));
      expect(sent.receiveTimeout, AssistantRepository.receiveTimeout);
      expect(sent.data, {
        'messages': [
          {'role': 'traveller', 'text': 'Visa?'},
          {'role': 'traveller', 'text': 'Visa, please?'},
        ],
        'context': {
          'destinationId': '3169070',
          'from': '2027-04-10',
          'to': '2027-04-15',
          'adults': 2,
          'passport': 'LB',
          'currency': 'USD',
        },
      });
    });

    test('sends only the last 20 messages', () async {
      final adapter = _Adapter({'text': 'ok', 'cards': <Object>[], 'warnings': <String>[]});
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = adapter;

      await AssistantRepository(dio).ask([for (var i = 0; i < 25; i++) _traveller('m$i')], _context);

      final messages = (adapter.last!.data as Map<String, Object?>)['messages']! as List<Object?>;
      expect(messages, hasLength(20));
      expect(messages.first, {'role': 'traveller', 'text': 'm5'});
    });
  });
}
