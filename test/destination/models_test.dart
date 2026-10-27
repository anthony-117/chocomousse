import 'package:chocomousse/features/destination/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  test('overview parses every section and keeps failed ones null', () {
    final overview = DestinationOverview.fromJson(overviewJson);

    expect(overview.destination.subtitle, 'Lazio, Italy');
    expect(overview.country?.currencies, ['EUR']);
    expect(overview.weather?.isForecast, isTrue);
    expect(overview.weather?.days, hasLength(2));
    expect(overview.exchange, isNull);
    expect(overview.holidays?.single.name, 'Easter Monday');
    expect(overview.visa?.label, 'Visa required');
    expect(overview.visa?.isFree, isFalse);
    expect(overview.advisory?.level, 2);
    expect(overview.warnings, ['Exchange rate is unavailable right now.']);
  });

  test('visa labels', () {
    expect(const VisaRequirement(requirement: 'visa free', visaFreeDays: 90).label, 'Visa free · 90 days');
    expect(const VisaRequirement(requirement: 'e-visa', visaFreeDays: null).label, 'e-Visa');
    expect(const VisaRequirement(requirement: 'own country', visaFreeDays: null).isFree, isTrue);
  });

  test('place parses category, location and optional fields', () {
    final place = Place.fromJson({
      'id': 'gp:abc',
      'name': 'Trattoria Da Enzo',
      'category': 'restaurant',
      'location': {'lat': 41.88, 'lng': 12.47},
      'kind': 'Roman restaurant',
      'rating': 4.6,
      'ratingCount': 9800,
      'priceLevel': r'$$',
      'openingHours': ['Monday: 12:30 – 15:00'],
      'source': 'Google Places',
    });

    expect(place.category, PlaceCategory.restaurant);
    expect(place.lat, 41.88);
    expect(place.imageUrl, isNull);
    expect(place.openingHours, hasLength(1));
  });
}
