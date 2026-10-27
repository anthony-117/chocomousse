import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/destination/data/models.dart';

/// Overview JSON as returned by pamplemousse (trimmed), with one failed section.
const Map<String, Object?> overviewJson = {
  'destination': {
    'id': '3169070',
    'name': 'Rome',
    'region': 'Lazio',
    'countryCode': 'IT',
    'countryName': 'Italy',
    'flag': '🇮🇹',
    'lat': 41.89193,
    'lng': 12.51133,
    'population': 2318895,
    'timeZone': 'Europe/Rome',
  },
  'country': {
    'code': 'IT',
    'name': 'Italy',
    'officialName': 'Italian Republic',
    'capital': 'Rome',
    'currencies': [
      {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
    ],
    'languages': ['Italian'],
    'callingCode': '+39',
    'flag': '🇮🇹',
  },
  'dates': {'from': '2027-04-10', 'to': '2027-04-14'},
  'weather': {
    'kind': 'forecast',
    'days': [
      {'date': '2027-04-10', 'maxC': 21.4, 'minC': 9.7, 'rainChance': 10, 'code': 1, 'summary': 'Mainly clear'},
      {'date': '2027-04-11', 'maxC': 19.0, 'minC': 8.0, 'rainChance': 30, 'code': 3, 'summary': 'Overcast'},
    ],
  },
  'exchange': null,
  'holidays': [
    {'date': '2027-04-12', 'name': 'Easter Monday', 'localName': "Lunedì dell'Angelo"},
  ],
  'visa': {'passport': 'LB', 'destination': 'IT', 'requirement': 'visa required', 'visaFreeDays': null},
  'advisory': {'level': 2, 'label': 'Exercise Increased Caution', 'summary': 'Be aware.', 'sourceUrl': 'https://x'},
  'warnings': ['Exchange rate is unavailable right now.'],
};

const rome = DestinationSummary(
  id: '3169070',
  name: 'Rome',
  region: 'Lazio',
  countryCode: 'IT',
  countryName: 'Italy',
  flag: '🇮🇹',
  lat: 41.89193,
  lng: 12.51133,
  timeZone: 'Europe/Rome',
);

const missingKeyWarning = 'OpenTripMap is not configured. Set OPENTRIPMAP_API_KEY in the environment or .env file.';

/// Builds a [Place] with sensible defaults for tests.
Place place({
  String id = 'otm:W3',
  String name = 'Colosseum',
  PlaceCategory category = PlaceCategory.attraction,
  String? kind = 'Amphitheatres',
  String? description,
  String? address,
  String? website,
  List<String> openingHours = const [],
  double? rating,
}) => Place(
  id: id,
  name: name,
  category: category,
  lat: 41.8902,
  lng: 12.4922,
  kind: kind,
  rating: rating,
  ratingCount: rating == null ? null : 1200,
  priceLevel: null,
  address: address,
  description: description,
  imageUrl: null,
  website: website,
  openingHours: openingHours,
  source: 'OpenTripMap',
);

/// Configurable stand-in for the API. Defaults mirror a backend without API keys.
class FakeDestinationRepository implements DestinationRepository {
  FakeDestinationRepository({
    this.attractions = const PlacesResult(items: [], warnings: [missingKeyWarning]),
    this.restaurants = const PlacesResult(items: [], warnings: [missingKeyWarning]),
    this.details,
    this.eventsResult = const EventsResult(items: [], warnings: []),
    this.countryOptions = const [],
    this.overviewError,
  });

  final PlacesResult attractions;
  final PlacesResult restaurants;
  final Place? details;
  final EventsResult eventsResult;
  final List<CountryOption> countryOptions;
  final Error? overviewError;

  final searches = <String>[];
  final overviewCalls = <({String passport, String currency})>[];
  final placesCalls = <PlaceCategory>[];

  @override
  Future<List<DestinationSummary>> search(String query) async {
    searches.add(query);
    return query.toLowerCase().startsWith('ro') ? [rome] : [];
  }

  @override
  Future<DestinationSummary> destination(String id) async => rome;

  @override
  Future<DestinationOverview> overview(
    String id, {
    required String passport,
    required String currency,
    required DateTime from,
    required DateTime to,
  }) async {
    overviewCalls.add((passport: passport, currency: currency));
    if (overviewError != null) throw overviewError!;
    return DestinationOverview.fromJson(overviewJson);
  }

  @override
  Future<PlacesResult> places(String id, PlaceCategory category) async {
    placesCalls.add(category);
    return category == PlaceCategory.attraction ? attractions : restaurants;
  }

  @override
  Future<Place> place(String placeId) async => details ?? (throw StateError('No details for $placeId'));

  @override
  Future<EventsResult> events(String id, {required DateTime from, required DateTime to}) async => eventsResult;

  @override
  Future<List<CountryOption>> countries() async => countryOptions;
}
