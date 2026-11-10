import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:flutter/foundation.dart';

// The chat models of API spec 010 (contracts/assistant-v2-api.md), read by hand (constitution I).

/// The trip a chat is about. Every field is optional; the composer's chips fill it.
@immutable
class ChatTrip {
  const ChatTrip({
    this.destinationId,
    this.destinationName,
    this.from,
    this.to,
    this.adults,
    this.originId,
    this.originName,
    this.passport,
    this.currency,
    this.tripBudget,
  });

  factory ChatTrip.fromJson(Map<String, dynamic> json) => ChatTrip(
    destinationId: json['destinationId'] as String?,
    destinationName: json['destinationName'] as String?,
    from: _dateOrNull(json['from']),
    to: _dateOrNull(json['to']),
    adults: json['adults'] as int?,
    originId: json['originId'] as String?,
    originName: json['originName'] as String?,
    passport: json['passport'] as String?,
    currency: json['currency'] as String?,
    tripBudget: json['tripBudget'] as num?,
  );

  static const empty = ChatTrip();

  final String? destinationId;
  final String? destinationName;
  final DateTime? from;
  final DateTime? to;
  final int? adults;
  final String? originId;

  /// App-only: the departure city's name for the chip. The API keeps only the id.
  final String? originName;
  final String? passport;
  final String? currency;
  final num? tripBudget;

  bool get isEmpty => destinationId == null && from == null && to == null && adults == null && originId == null;

  /// The request's `trip`, null fields left out. The names are the app's own and aren't sent.
  Map<String, Object?> toJson() => {
    'destinationId': ?destinationId,
    'from': ?_formatDate(from),
    'to': ?_formatDate(to),
    'adults': ?adults,
    'originId': ?originId,
    'passport': ?passport,
    'currency': ?currency,
    'tripBudget': ?tripBudget,
  };

  ChatTrip copyWith({
    String? destinationId,
    String? destinationName,
    DateTime? from,
    DateTime? to,
    int? adults,
    String? originId,
    String? originName,
    String? passport,
    String? currency,
    num? tripBudget,
  }) => ChatTrip(
    destinationId: destinationId ?? this.destinationId,
    destinationName: destinationName ?? this.destinationName,
    from: from ?? this.from,
    to: to ?? this.to,
    adults: adults ?? this.adults,
    originId: originId ?? this.originId,
    originName: originName ?? this.originName,
    passport: passport ?? this.passport,
    currency: currency ?? this.currency,
    tripBudget: tripBudget ?? this.tripBudget,
  );

  @override
  bool operator ==(Object other) =>
      other is ChatTrip &&
      other.destinationId == destinationId &&
      other.destinationName == destinationName &&
      other.from == from &&
      other.to == to &&
      other.adults == adults &&
      other.originId == originId &&
      other.originName == originName &&
      other.passport == passport &&
      other.currency == currency &&
      other.tripBudget == tripBudget;

  @override
  int get hashCode => Object.hash(
    destinationId,
    destinationName,
    from,
    to,
    adults,
    originId,
    originName,
    passport,
    currency,
    tripBudget,
  );
}

/// A line of Recents.
@immutable
class ChatListItem {
  const ChatListItem({
    required this.id,
    required this.createdAt,
    required this.lastMessageAt,
    required this.messageCount,
    this.title,
    this.trip,
  });

  factory ChatListItem.fromJson(Map<String, dynamic> json) => ChatListItem(
    id: json['id']! as String,
    title: json['title'] as String?,
    trip: _trip(json['trip']),
    createdAt: _time(json['createdAt']),
    lastMessageAt: _time(json['lastMessageAt']),
    messageCount: json['messageCount'] as int? ?? 0,
  );

  final String id;
  final String? title;
  final ChatTrip? trip;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final int messageCount;
}

/// A page of Recents. [next] is the cursor of the next page, null on the last one.
@immutable
class ChatPage {
  const ChatPage({required this.items, required this.keepDays, this.next});

  factory ChatPage.fromJson(Map<String, dynamic> json) => ChatPage(
    items: _maps(json['items']).map(ChatListItem.fromJson).toList(),
    next: json['next'] as String?,
    keepDays: json['keepDays'] as int? ?? 90,
  );

  final List<ChatListItem> items;
  final String? next;

  /// How long chats are kept after their last message ("Chats are kept for 90 days.").
  final int keepDays;
}

/// A chat and its messages, oldest first.
@immutable
class Chat {
  const Chat({
    required this.id,
    required this.createdAt,
    required this.lastMessageAt,
    required this.expiresAt,
    required this.busy,
    required this.messages,
    this.title,
    this.trip,
    this.preferences,
    this.pace,
  });

  factory Chat.fromJson(Map<String, dynamic> json) => Chat(
    id: json['id']! as String,
    title: json['title'] as String?,
    trip: _trip(json['trip']),
    preferences: _weights(json['preferences']),
    pace: json['pace'] == null ? null : Pace.parse(json['pace'] as String?),
    createdAt: _time(json['createdAt']),
    lastMessageAt: _time(json['lastMessageAt']),
    expiresAt: _time(json['expiresAt']),
    busy: json['busy'] as bool? ?? false,
    messages: _maps(json['messages']).map(ChatMessage.fromJson).toList(),
  );

  final String id;
  final String? title;
  final ChatTrip? trip;

  /// The six weights (0–100) last sent, by criterion name.
  final Map<String, int>? preferences;
  final Pace? pace;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final DateTime expiresAt;

  /// An answer is still running, on another device.
  final bool busy;
  final List<ChatMessage> messages;
}

enum ChatRole { traveller, assistant }

/// What a message is about: a plan, a day of it, or an item of that day.
@immutable
class MessageAbout {
  const MessageAbout({required this.planId, this.day, this.itemId});

  factory MessageAbout.fromJson(Map<String, dynamic> json) =>
      MessageAbout(planId: json['planId']! as String, day: json['day'] as int?, itemId: json['itemId'] as String?);

  final String planId;
  final int? day;
  final String? itemId;

  Map<String, Object?> toJson() => {'planId': planId, 'day': ?day, 'itemId': ?itemId};

  @override
  bool operator ==(Object other) =>
      other is MessageAbout && other.planId == planId && other.day == day && other.itemId == itemId;

  @override
  int get hashCode => Object.hash(planId, day, itemId);
}

/// One tool the assistant ran ("Searched flights Beirut → Rome · 23 fares").
@immutable
class ToolStep {
  const ToolStep({required this.tool, required this.summary, required this.ok, this.total, this.cards = const []});

  factory ToolStep.fromJson(Map<String, dynamic> json) => ToolStep(
    tool: json['tool'] as String? ?? '',
    summary: json['summary'] as String? ?? '',
    ok: json['ok'] as bool? ?? true,
    total: json['total'] as int?,
    cards: readCards(json['cards']),
  );

  /// The tool's name; the app uses it only for the step's icon.
  final String tool;
  final String summary;
  final bool ok;

  /// How many were found, for "See all N"; null when it doesn't apply.
  final int? total;
  final List<AssistantCard> cards;
}

/// A message of a chat. [notSent] is the app's own: the traveller's message whose answer failed.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.at,
    this.about,
    this.steps = const [],
    this.cards = const [],
    this.suggestions = const [],
    this.warnings = const [],
    this.planChanged,
    this.notSent = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id']! as String,
    role: json['role'] == 'traveller' ? ChatRole.traveller : ChatRole.assistant,
    text: json['text'] as String? ?? '',
    about: json['about'] is Map<String, dynamic> ? MessageAbout.fromJson(json['about'] as Map<String, dynamic>) : null,
    steps: _maps(json['steps']).map(ToolStep.fromJson).toList(),
    cards: readCards(json['cards']),
    suggestions: _strings(json['suggestions']),
    warnings: _strings(json['warnings']),
    planChanged: json['planChanged'] as String?,
    at: _time(json['at']),
  );

  /// The `final` event: an assistant message, with its id under `messageId`.
  factory ChatMessage.fromFinal(Map<String, dynamic> json, {List<ToolStep> steps = const []}) => ChatMessage(
    id: json['messageId'] as String? ?? '',
    role: ChatRole.assistant,
    text: json['text'] as String? ?? '',
    steps: steps,
    cards: readCards(json['cards']),
    suggestions: _strings(json['suggestions']),
    warnings: _strings(json['warnings']),
    planChanged: json['planChanged'] as String?,
    at: json['at'] == null ? DateTime.now() : _time(json['at']),
  );

  final String id;
  final ChatRole role;
  final String text;
  final MessageAbout? about;
  final List<ToolStep> steps;
  final List<AssistantCard> cards;
  final List<String> suggestions;
  final List<String> warnings;

  /// The id of a plan this answer built or changed, so the panel reloads it.
  final String? planChanged;
  final DateTime at;
  final bool notSent;

  bool get isTraveller => role == ChatRole.traveller;

  ChatMessage copyWith({String? id, bool? notSent, List<ToolStep>? steps}) => ChatMessage(
    id: id ?? this.id,
    role: role,
    text: text,
    at: at,
    about: about,
    steps: steps ?? this.steps,
    cards: cards,
    suggestions: suggestions,
    warnings: warnings,
    planChanged: planChanged,
    notSent: notSent ?? this.notSent,
  );
}

/// The answer of `GET /assistant/chats/search`.
@immutable
class ChatSearchResult {
  const ChatSearchResult({required this.chats, required this.plans});

  factory ChatSearchResult.fromJson(Map<String, dynamic> json) => ChatSearchResult(
    chats: _maps(json['chats']).map(ChatListItem.fromJson).toList(),
    plans: _maps(json['plans']).map(PlanSummary.fromJson).toList(),
  );

  final List<ChatListItem> chats;
  final List<PlanSummary> plans;

  bool get isEmpty => chats.isEmpty && plans.isEmpty;
}

/// A message to send.
@immutable
class ChatRequest {
  ChatRequest({required String text, this.trip, this.preferences, this.pace, this.about}) : text = text.trim() {
    final error = textError(text);
    if (error != null) throw ArgumentError.value(text, 'text', error);
  }

  static const maxLength = 1000;

  /// Why [text] can't be sent, or null: it is 1–1,000 characters after trimming.
  static String? textError(String text) {
    final length = text.trim().length;
    if (length == 0) return 'Write a message first.';
    if (length > maxLength) return 'Keep it under $maxLength characters.';
    return null;
  }

  final String text;
  final ChatTrip? trip;

  /// The six weights, 0–100, by criterion name.
  final Map<String, int>? preferences;
  final Pace? pace;
  final MessageAbout? about;

  Map<String, Object?> toJson() {
    final tripJson = trip?.toJson();
    return {
      'text': text,
      if (tripJson != null && tripJson.isNotEmpty) 'trip': tripJson,
      'preferences': ?preferences,
      'pace': ?pace?.name,
      'about': ?about?.toJson(),
    };
  }
}

ChatTrip? _trip(Object? json) => json is Map<String, dynamic> ? ChatTrip.fromJson(json) : null;

Map<String, int>? _weights(Object? json) =>
    json is Map<String, dynamic> ? {for (final e in json.entries) e.key: (e.value as num).round()} : null;

Iterable<Map<String, dynamic>> _maps(Object? json) => json is List ? json.whereType<Map<String, dynamic>>() : const [];

List<String> _strings(Object? json) => json is List ? json.whereType<String>().toList() : const [];

DateTime _time(Object? json) => DateTime.parse(json! as String);

DateTime? _dateOrNull(Object? json) => json is String ? DateTime.parse(json) : null;

String? _formatDate(DateTime? date) => date == null
    ? null
    : '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
