import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/destination/data/models.dart';

/// Overview JSON as returned by pamplemousse (trimmed), with one failed section.
const overviewJson = {
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

class FakeDestinationRepository implements DestinationRepository {
  final searches = <String>[];

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
  }) async => DestinationOverview.fromJson(overviewJson);

  @override
  Future<PlacesResult> places(String id, PlaceCategory category) async => const PlacesResult(
    items: [],
    warnings: ['OpenTripMap is not configured. Set OPENTRIPMAP_API_KEY in the environment or .env file.'],
  );

  @override
  Future<Place> place(String placeId) => throw UnimplementedError();

  @override
  Future<EventsResult> events(String id, {required DateTime from, required DateTime to}) async =>
      const EventsResult(items: [], warnings: []);

  @override
  Future<List<CountryOption>> countries() async => const [];
}
