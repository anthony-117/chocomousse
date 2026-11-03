import 'package:chocomousse/features/flights/application/flight_providers.dart';
import 'package:chocomousse/features/flights/data/flight_models.dart';
import 'package:chocomousse/features/flights/data/flight_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../destination/fakes.dart';
import 'fakes.dart';

FlightQuery _query({bool directOnly = false}) => (
  destinationId: '3169070',
  originId: '2988507',
  from: DateTime(2027, 4, 10),
  to: DateTime(2027, 4, 14),
  currency: 'USD',
  tripType: FlightTripType.roundTrip,
  directOnly: directOnly,
);

void main() {
  test('the departure city starts empty and stays once chosen', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(departureCityProvider), isNull);

    container.read(departureCityProvider.notifier).choose(rome);

    expect(container.read(departureCityProvider), rome);
  });

  test('equal searches share one request, and a different one makes another', () async {
    final flights = FakeFlightRepository();
    final container = ProviderContainer(overrides: [flightRepositoryProvider.overrideWithValue(flights)]);
    addTearDown(container.dispose);

    final first = container.listen(flightResultsProvider(_query()), (_, _) {});
    final same = container.listen(flightResultsProvider(_query()), (_, _) {});
    await container.read(flightResultsProvider(_query()).future);
    expect(flights.queries, hasLength(1));

    final other = container.listen(flightResultsProvider(_query(directOnly: true)), (_, _) {});
    await container.read(flightResultsProvider(_query(directOnly: true)).future);
    expect(flights.queries, hasLength(2));

    first.close();
    same.close();
    other.close();
  });
}
