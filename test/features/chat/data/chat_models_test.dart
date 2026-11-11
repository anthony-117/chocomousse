import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../itinerary/fakes.dart';
import '../fakes.dart';

final _listItem = <String, dynamic>{
  'id': 'c1',
  'title': 'Rome in April for two',
  'trip': {
    'destinationId': '3169070',
    'destinationName': 'Rome',
    'from': '2027-04-10',
    'to': '2027-04-14',
    'adults': 2,
  },
  'createdAt': '2026-11-09T18:40:00Z',
  'lastMessageAt': '2026-11-10T19:02:11Z',
  'messageCount': 6,
};

void main() {
  test('reads a chat list item and its trip', () {
    final item = ChatListItem.fromJson(_listItem);
    expect(item.id, 'c1');
    expect(item.title, 'Rome in April for two');
    expect(item.trip!.destinationName, 'Rome');
    expect(item.trip!.from, DateTime(2027, 4, 10));
    expect(item.trip!.adults, 2);
    expect(item.lastMessageAt, DateTime.utc(2026, 11, 10, 19, 2, 11));
    expect(item.messageCount, 6);
  });

  test('reads a chat page', () {
    final page = ChatPage.fromJson({
      'items': [_listItem],
      'next': 'cursor-2',
      'keepDays': 90,
    });
    expect(page.items.single.id, 'c1');
    expect(page.next, 'cursor-2');
    expect(page.keepDays, 90);
  });

  test('reads a chat with its messages, steps and cards', () {
    final chat = Chat.fromJson({
      'id': 'c1',
      'title': 'Rome',
      'trip': const {'destinationId': '3169070'},
      'preferences': const {'budget': 90, 'culture': 90, 'food': 50, 'nature': 20, 'nightlife': 20, 'comfort': 50},
      'pace': 'relaxed',
      'createdAt': '2026-11-09T18:40:00Z',
      'lastMessageAt': '2026-11-10T19:02:11Z',
      'expiresAt': '2027-02-08T19:02:11Z',
      'busy': true,
      'messages': [
        const {
          'id': '0001',
          'role': 'traveller',
          'text': 'Change day 2',
          'about': {'planId': 'p1', 'day': 2, 'itemId': 'wd:Q10285'},
          'at': '2026-11-10T19:00:00Z',
        },
        {
          'id': '0002',
          'role': 'assistant',
          'text': 'Here is…',
          'steps': [stepJson()],
          'cards': [planCardJson(), envelope('train', 't', {})],
          'suggestions': const ['Add a car'],
          'warnings': const ['Weather unavailable'],
          'planChanged': 'p1',
          'at': '2026-11-10T19:02:11Z',
        },
      ],
    });
    expect(chat.busy, isTrue);
    expect(chat.pace, Pace.relaxed);
    expect(chat.preferences!['budget'], 90);
    expect(chat.expiresAt, DateTime.utc(2027, 2, 8, 19, 2, 11));

    final asked = chat.messages.first;
    expect(asked.isTraveller, isTrue);
    expect(asked.about, const MessageAbout(planId: 'p1', day: 2, itemId: 'wd:Q10285'));
    expect(asked.steps, isEmpty);

    final answer = chat.messages.last;
    expect(answer.role, ChatRole.assistant);
    expect(answer.steps.single.summary, 'Searched flights Beirut → Rome · 23 fares');
    expect(answer.steps.single.total, 23);
    expect(answer.steps.single.cards.single, isA<FlightCard>());
    expect(answer.cards.single, isA<PlanCard>());
    expect(answer.suggestions, ['Add a car']);
    expect(answer.warnings, ['Weather unavailable']);
    expect(answer.planChanged, 'p1');
    expect(answer.notSent, isFalse);
  });

  test('reads the final event as an assistant message', () {
    final message = ChatMessage.fromFinal(finalJson(planChanged: 'p1').cast());
    expect(message.id, '0002');
    expect(message.role, ChatRole.assistant);
    expect(message.text, 'Here is a 5-day plan.');
    expect(message.cards.single, isA<PlanCard>());
    expect(message.planChanged, 'p1');
  });

  test('reads a search result', () {
    final result = ChatSearchResult.fromJson({
      'chats': [_listItem],
      'plans': [summaryJson()],
    });
    expect(result.chats.single.id, 'c1');
    expect(result.plans.single.name, 'Rome, 5 days');
    expect(result.isEmpty, isFalse);
  });

  group('ChatRequest', () {
    test('trims the text and leaves out nulls', () {
      final request = ChatRequest(text: '  Plan Rome  ');
      expect(request.toJson(), {'text': 'Plan Rome'});
    });

    test('sends the trip, preferences, pace and about', () {
      final request = ChatRequest(
        text: 'Plan Rome',
        trip: ChatTrip(destinationId: '3169070', destinationName: 'Rome', from: DateTime(2027, 4, 10), adults: 2),
        preferences: const {'budget': 90},
        pace: Pace.packed,
        about: const MessageAbout(planId: 'p1', day: 2),
      );
      expect(request.toJson(), {
        'text': 'Plan Rome',
        'trip': {'destinationId': '3169070', 'from': '2027-04-10', 'adults': 2},
        'preferences': {'budget': 90},
        'pace': 'packed',
        'about': {'planId': 'p1', 'day': 2},
      });
    });

    test('an empty trip is left out', () {
      expect(ChatRequest(text: 'Hi', trip: ChatTrip.empty).toJson(), {'text': 'Hi'});
    });

    test('text is 1–1,000 characters after trimming', () {
      expect(ChatRequest.textError('   '), isNotNull);
      expect(ChatRequest.textError('a' * 1000), isNull);
      expect(ChatRequest.textError('a' * 1001), isNotNull);
      expect(() => ChatRequest(text: ' '), throwsArgumentError);
    });
  });
}
