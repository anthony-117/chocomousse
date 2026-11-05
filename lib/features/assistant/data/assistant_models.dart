/// Who wrote a chat message.
enum ChatRole { traveller, assistant }

/// The screen an assistant card opens.
enum AssistantCardKind { overview, places, flights, hotels }

/// A link into an existing screen, for a search the assistant ran (spec 003, FR-002).
class AssistantCard {
  const AssistantCard({
    required this.kind,
    required this.destinationId,
    required this.title,
    required this.subtitle,
    this.from,
    this.to,
    this.adults,
    this.originId,
    this.category,
  });

  final AssistantCardKind kind;
  final String destinationId;
  final String title;
  final String subtitle;
  final DateTime? from;
  final DateTime? to;
  final int? adults;

  /// Departure city, for flights.
  final String? originId;

  /// `attraction` or `restaurant`, for places.
  final String? category;

  /// Null for a kind this version of the app doesn't know, so a newer API never breaks the chat.
  static AssistantCard? fromJson(Map<String, dynamic> json) {
    final kind = AssistantCardKind.values.asNameMap()[json['kind']];
    if (kind == null) return null;
    return AssistantCard(
      kind: kind,
      destinationId: json['destinationId'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      from: _date(json['from']),
      to: _date(json['to']),
      adults: json['adults'] as int?,
      originId: json['originId'] as String?,
      category: json['category'] as String?,
    );
  }

  /// The route of the screen this card opens.
  String get route {
    final base = '/discover/destination/$destinationId';
    return switch (kind) {
      AssistantCardKind.overview => base,
      AssistantCardKind.places => '$base/places?category=${category ?? 'attraction'}',
      AssistantCardKind.flights => '$base/flights',
      AssistantCardKind.hotels => '$base/hotels',
    };
  }

  /// Short label above the title, as in the design's ActionCard.
  String get label => switch (kind) {
    AssistantCardKind.overview => 'CITY GUIDE',
    AssistantCardKind.places => category == 'restaurant' ? 'RESTAURANTS' : 'ATTRACTIONS',
    AssistantCardKind.flights => 'FLIGHTS',
    AssistantCardKind.hotels => 'HOTELS',
  };
}

/// What the API answered. [text] is empty when the assistant could not answer; [warnings] then says why.
class AssistantReply {
  const AssistantReply({required this.text, required this.cards, required this.warnings});

  factory AssistantReply.fromJson(Map<String, dynamic> json) => AssistantReply(
    text: json['text'] as String? ?? '',
    cards: [
      for (final card in json['cards'] as List<dynamic>? ?? const [])
        ?AssistantCard.fromJson(card as Map<String, dynamic>),
    ],
    warnings: [for (final w in json['warnings'] as List<dynamic>? ?? const []) w as String],
  );

  final String text;
  final List<AssistantCard> cards;
  final List<String> warnings;
}

/// One message in the chat, as the app shows it.
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    this.cards = const [],
    this.warnings = const [],
    this.notSent = false,
  });

  final ChatRole role;
  final String text;
  final List<AssistantCard> cards;
  final List<String> warnings;

  /// A traveller message whose request failed; Try again resends it.
  final bool notSent;

  /// An assistant message that only explains why there is no answer (busy, not configured).
  bool get isWarningOnly => role == ChatRole.assistant && text.isEmpty;

  ChatMessage copyWith({bool? notSent}) =>
      ChatMessage(role: role, text: text, cards: cards, warnings: warnings, notSent: notSent ?? this.notSent);
}

/// The trip sent with each message; every value is optional on the API side.
class ChatContext {
  const ChatContext({
    required this.from,
    required this.to,
    required this.adults,
    required this.passport,
    required this.currency,
    this.destinationId,
    this.originId,
  });

  final String? destinationId;
  final DateTime from;
  final DateTime to;
  final int adults;
  final String passport;
  final String currency;
  final String? originId;

  Map<String, Object?> toJson() => {
    'destinationId': ?destinationId,
    'from': _day(from),
    'to': _day(to),
    'adults': adults,
    'passport': passport,
    'currency': currency,
    'originId': ?originId,
  };
}

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value) : null;
