import 'dart:async';
import 'dart:convert';

import 'package:chocomousse/features/chat/application/recents.dart';
import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/chat/data/chat_repository.dart';
import 'package:chocomousse/features/chat/data/chat_transport.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../cars/fakes.dart';
import '../../flights/fakes.dart';
import '../../hotels/fakes.dart';
import '../../itinerary/fakes.dart';
import '../../ranking/fakes.dart';

/// A card envelope as the API sends it.
Map<String, Object?> envelope(
  String kind,
  String id,
  Map<String, Object?> item, {
  double lat = 41.9,
  double lng = 12.49,
  bool approximate = false,
}) => {
  'kind': kind,
  'id': id,
  'lat': lat,
  'lng': lng,
  'approximate': approximate,
  'foundAt': '2026-11-10T19:02:05Z',
  'item': item,
};

Map<String, Object?> planCardJson({String id = 'p1', String name = 'Rome, 5 days'}) => envelope('plan', id, {
  ...summaryJson(id: id, name: name),
  'destinationId': '3169070',
  'adults': 2,
  'tripBudget': 1200,
  'pace': 'packed',
  'lat': 41.9,
  'lng': 12.49,
});

Map<String, Object?> flightCardJson({bool withMatch = true}) =>
    envelope('flight', 'tp:1', {...fareJson(), 'match': withMatch ? matchJson() : null}, approximate: true);

Map<String, Object?> hotelCardJson({String id = 'bk:1', bool withMatch = true}) =>
    envelope('hotel', id, {...hotelJson(id: id), 'match': withMatch ? matchJson(percent: 88) : null});

Map<String, Object?> carCardJson() => envelope('car', 'bk:car:1', {...carJson(), 'match': null});

Map<String, Object?> placeItemJson({String id = 'wd:Q10285', String name = 'Colosseum'}) => {
  'id': id,
  'name': name,
  'category': 'attraction',
  'location': {'lat': 41.89, 'lng': 12.49},
  'kind': 'amphitheatre',
  'rating': 4.7,
  'imageUrl': 'https://upload.wikimedia.org/colosseum.jpg',
  'source': 'wikidata',
};

Map<String, Object?> placeCardJson({String id = 'wd:Q10285'}) => envelope('place', id, placeItemJson(id: id));

Map<String, Object?> eventCardJson({bool withLocation = true}) => envelope('event', 'tm:9', {
  'id': 'tm:9',
  'name': 'Jazz at the Baths',
  'date': '2027-04-11',
  'time': '21:00',
  'venue': 'Terme di Caracalla',
  'category': 'Music',
  'priceFrom': {'amount': 35, 'currency': 'EUR'},
  'url': 'https://www.ticketmaster.it/event/9',
  if (withLocation) 'location': {'lat': 41.879, 'lng': 12.492},
}, approximate: !withLocation);

Map<String, Object?> factsCardJson() => envelope('facts', '4219762', {
  'destination': {'id': '4219762', 'name': 'Istanbul', 'countryCode': 'TR'},
  'from': '2027-05-02',
  'to': '2027-05-06',
  'weather': {'kind': 'forecast', 'summary': 'Mild, some rain', 'maxC': 21, 'minC': 13, 'rainChance': 40},
  'visa': {'passport': 'LB', 'requirement': 'e-visa', 'visaFreeDays': null},
  'currency': {'from': 'USD', 'to': 'TRY', 'rate': 34.1, 'date': '2026-11-10'},
  'safety': {'level': 2, 'label': 'Exercise increased caution', 'summary': 'Take care in crowds.'},
  'holidays': [
    {'date': '2027-05-01', 'name': 'Labour Day'},
  ],
}, approximate: true);

Map<String, Object?> stepJson({
  String tool = 'search_flights',
  String summary = 'Searched flights Beirut → Rome · 23 fares',
  bool ok = true,
  int? total = 23,
  List<Map<String, Object?>>? cards,
}) => {
  'tool': tool,
  'summary': summary,
  'ok': ok,
  'total': total,
  'cards': cards ?? [flightCardJson()],
};

Map<String, Object?> finalJson({
  String messageId = '0002',
  String? title = 'Rome in April for two',
  String text = 'Here is a 5-day plan.',
  List<Map<String, Object?>>? cards,
  List<String> suggestions = const ['Add a car'],
  List<String> warnings = const [],
  String? planChanged,
}) => {
  'messageId': messageId,
  'title': title,
  'text': text,
  'cards': cards ?? [planCardJson()],
  'suggestions': suggestions,
  'warnings': warnings,
  'planChanged': planChanged,
  'at': '2026-11-10T19:02:11Z',
};

/// One SSE event as text.
String sse(String name, Object data) => 'event: $name\ndata: ${jsonEncode(data)}\n\n';

/// A whole answer: chat, the steps, then final.
String answerSse({String chatId = 'c1', List<Map<String, Object?>>? steps, Map<String, Object?>? last}) => [
  sse('chat', {'chatId': chatId, 'title': null, 'messageId': '0001'}),
  for (final step in steps ?? [stepJson()]) sse('step', step),
  sse('final', last ?? finalJson()),
].join();

/// Answers each post with the next scripted reply: a [String] of SSE text, a [Stream] of bytes, or an error to throw
/// (e.g. a [ChatRefused]). It remembers each path and body.
class FakeChatTransport implements ChatTransport {
  FakeChatTransport([List<Object>? replies]) : _replies = [...?replies];

  final List<Object> _replies;
  final posts = <({String path, Map<String, Object?> body})>[];

  void reply(Object answer) => _replies.add(answer);

  @override
  Future<Stream<List<int>>> post(String path, Map<String, Object?> body) async {
    posts.add((path: path, body: body));
    final next = _replies.isEmpty ? answerSse() : _replies.removeAt(0);
    return switch (next) {
      final String text => Stream.value(utf8.encode(text)),
      final Stream<List<int>> stream => stream,
      _ => throw next as Exception,
    };
  }
}

/// Recents with no chats, so nothing asks the API for the list.
class EmptyRecents extends RecentsController {
  @override
  Future<RecentsState> build() async => const RecentsState(items: [], keepDays: 90);
}

/// The chat API answered by [transport] (messages) and [answers] (every other call), with empty Recents.
List<Override> chatOverrides(FakeChatTransport transport, {List<(int, Object?)> answers = const []}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))..httpClientAdapter = ScriptedAdapter([...answers]);
  return [
    chatRepositoryProvider.overrideWithValue(ChatRepository(dio, transport)),
    recentsProvider.overrideWith(EmptyRecents.new),
  ];
}

/// A stored chat as the API sends it.
Map<String, Object?> chatJson({
  String id = 'c1',
  String? title = 'Rome in April',
  List<Map<String, Object?>>? messages,
  Map<String, Object?>? trip,
  Map<String, Object?>? preferences,
  String? pace,
  bool busy = false,
}) => {
  'id': id,
  'title': title,
  'trip': trip,
  'preferences': preferences,
  'pace': pace,
  'createdAt': '2026-11-09T18:40:00Z',
  'lastMessageAt': '2026-11-10T19:02:11Z',
  'expiresAt': '2027-02-08T19:02:11Z',
  'busy': busy,
  'messages':
      messages ??
      [
        {'id': '0001', 'role': 'traveller', 'text': 'Plan Rome', 'at': '2026-11-10T19:00:00Z'},
        {
          'id': '0002',
          'role': 'assistant',
          'text': 'Here is a 5-day plan.',
          'steps': <Object>[],
          'cards': [planCardJson()],
          'at': '2026-11-10T19:02:11Z',
        },
      ],
};

/// The chat API held in memory: Recents pages of [pageSize], open, rename, delete and search over titles and texts.
/// Messages go through [transport].
class FakeChatApi extends ChatRepository {
  factory FakeChatApi({FakeChatTransport? transport, List<Map<String, Object?>> chats = const [], int pageSize = 30}) =>
      FakeChatApi._(transport ?? FakeChatTransport(), [...chats], pageSize);

  FakeChatApi._(this.transport, this.chats, this.pageSize) : super(Dio(), transport);

  final FakeChatTransport transport;

  final List<Map<String, Object?>> chats;
  final int pageSize;
  int keepDays = 90;
  List<Map<String, Object?>> plans = [];

  /// The next call of each kind fails with it, once.
  Exception? failList;
  Exception? failSearch;
  Exception? failRename;

  /// When set, list waits for it.
  Completer<void>? gate;

  final searches = <String>[];

  static Map<String, Object?> _item(Map<String, Object?> chat) => {
    'id': chat['id'],
    'title': chat['title'],
    'trip': chat['trip'],
    'createdAt': chat['createdAt'],
    'lastMessageAt': chat['lastMessageAt'],
    'messageCount': (chat['messages']! as List).length,
  };

  @override
  Future<ChatPage> list({String? before, int limit = 30}) async {
    await gate?.future;
    if (failList case final failure?) {
      failList = null;
      throw failure;
    }
    final start = before == null ? 0 : int.parse(before);
    final end = (start + pageSize).clamp(0, chats.length);
    return ChatPage.fromJson({
      'items': chats.sublist(start, end).map(_item).toList(),
      'next': end < chats.length ? '$end' : null,
      'keepDays': keepDays,
    });
  }

  @override
  Future<Chat> get(String id) async {
    final chat = chats.where((c) => c['id'] == id).firstOrNull;
    if (chat == null) throw const ChatNotFound();
    return Chat.fromJson(chat);
  }

  @override
  Future<ChatListItem> rename(String id, String title) async {
    if (failRename case final failure?) {
      failRename = null;
      throw failure;
    }
    final i = chats.indexWhere((c) => c['id'] == id);
    chats[i] = {...chats[i], 'title': title.trim()};
    return ChatListItem.fromJson(_item(chats[i]));
  }

  @override
  Future<void> delete(String id) async => chats.removeWhere((c) => c['id'] == id);

  @override
  Future<ChatSearchResult> search(String q) async {
    searches.add(q);
    if (failSearch case final failure?) {
      failSearch = null;
      throw failure;
    }
    final needle = q.trim().toLowerCase();
    bool has(Object? text) => text is String && text.toLowerCase().contains(needle);
    return ChatSearchResult.fromJson({
      'chats': [
        for (final chat in chats)
          if (has(chat['title']) || (chat['messages']! as List).any((m) => has((m as Map)['text']))) _item(chat),
      ],
      'plans': [
        for (final plan in plans)
          if (has(plan['name'])) plan,
      ],
    });
  }
}

/// The chat API answered by [api], with the real Recents.
List<Override> chatApiOverrides(FakeChatApi api) => [chatRepositoryProvider.overrideWithValue(api)];
