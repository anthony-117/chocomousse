import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:flutter/foundation.dart';

/// What can be saved: hotels, places and events (spec 008 US6). Flights and cars are kept in plans.
enum SavedKind {
  hotel('Hotels'),
  place('Places'),
  event('Events');

  SavedKind(this.groupLabel);

  /// The heading of the kind's group in the Saved pane.
  final String groupLabel;

  /// The API's value, or null for any other.
  static SavedKind? parse(Object? value) => values.asNameMap()[value];

  /// The kind of [card], or null when it can't be saved.
  static SavedKind? of(AssistantCard card) => switch (card) {
    HotelCard() => hotel,
    PlaceCard() => place,
    EventCard() => event,
    _ => null,
  };
}

/// One saved hotel, place or event, with what the Saved pane needs to show it without another search.
@immutable
class SavedItem {
  const SavedItem({
    required this.kind,
    required this.id,
    required this.destinationId,
    required this.destinationName,
    required this.name,
    required this.lat,
    required this.lng,
    required this.savedAt,
    this.imageUrl,
    this.card,
  });

  /// The item, or null when its kind isn't one the app knows.
  static SavedItem? fromJson(Map<String, dynamic> json) {
    final kind = SavedKind.parse(json['kind']);
    if (kind == null) return null;
    final id = json['id']! as String;
    final lat = (json['lat']! as num).toDouble();
    final lng = (json['lng']! as num).toDouble();
    final item = json['item'];
    return SavedItem(
      kind: kind,
      id: id,
      destinationId: json['destinationId']! as String,
      destinationName: json['destinationName'] as String? ?? '',
      name: json['name']! as String,
      imageUrl: json['imageUrl'] as String?,
      lat: lat,
      lng: lng,
      savedAt: DateTime.parse(json['savedAt']! as String),
      card: item is Map<String, dynamic>
          ? AssistantCard.fromJson({
              'kind': kind.name,
              'id': id,
              'lat': lat,
              'lng': lng,
              'approximate': false,
              'destinationId': json['destinationId'],
              'destinationName': json['destinationName'],
              'item': item,
            })
          : null,
    );
  }

  final SavedKind kind;
  final String id;
  final String destinationId;
  final String destinationName;
  final String name;
  final String? imageUrl;
  final double lat;
  final double lng;
  final DateTime savedAt;

  /// The stored item read back into its card, so it opens in Details. Null when it was too big to keep, or no
  /// longer reads.
  final AssistantCard? card;
}

/// `GET /saved`: newest first, with the account's count and limit.
@immutable
class SavedList {
  const SavedList({required this.items, required this.count, required this.max});

  factory SavedList.fromJson(Map<String, dynamic> json) => SavedList(
    items: (json['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SavedItem.fromJson)
        .whereType<SavedItem>()
        .toList(),
    count: json['count'] as int? ?? 0,
    max: json['max'] as int? ?? 0,
  );

  final List<SavedItem> items;
  final int count;
  final int max;

  /// The items of [kind], newest first.
  List<SavedItem> of(SavedKind kind) =>
      items.where((i) => i.kind == kind).toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));
}

/// `GET /saved/ids`: the ids saved, by kind, so every card can show its bookmark.
@immutable
class SavedIds {
  const SavedIds({this.hotel = const {}, this.place = const {}, this.event = const {}});

  factory SavedIds.fromJson(Map<String, dynamic> json) {
    Set<String> read(String key) => {...(json[key] as List? ?? const []).whereType<String>()};
    return SavedIds(hotel: read('hotel'), place: read('place'), event: read('event'));
  }

  static const empty = SavedIds();

  final Set<String> hotel;
  final Set<String> place;
  final Set<String> event;

  Set<String> of(SavedKind kind) => switch (kind) {
    SavedKind.hotel => hotel,
    SavedKind.place => place,
    SavedKind.event => event,
  };

  bool contains(SavedKind kind, String id) => of(kind).contains(id);

  /// These ids with [id] saved, or removed when [saved] is false.
  SavedIds withId(SavedKind kind, String id, {required bool saved}) {
    final ids = {...of(kind)};
    if (saved) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    return SavedIds(
      hotel: kind == SavedKind.hotel ? ids : hotel,
      place: kind == SavedKind.place ? ids : place,
      event: kind == SavedKind.event ? ids : event,
    );
  }
}
