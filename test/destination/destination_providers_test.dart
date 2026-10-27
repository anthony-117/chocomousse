import 'package:chocomousse/env.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late FakeDestinationRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeDestinationRepository();
    container = ProviderContainer(overrides: [destinationRepositoryProvider.overrideWithValue(repo)]);
  });
  tearDown(() {
    container.dispose();
    Env.reset();
  });

  test('trip defaults: env passport and currency, 5-day trip starting in 30 days', () {
    final trip = container.read(tripSettingsProvider);
    final today = DateTime.now();

    expect(trip.passport, Env.defaultPassport);
    expect(trip.currency, Env.defaultCurrency);
    expect(trip.from.difference(DateTime(today.year, today.month, today.day)).inDays, 30);
    expect(trip.nights, 4);
  });

  test('trip settings can be changed', () {
    container.read(tripSettingsProvider.notifier)
      ..setPassport('FR')
      ..setCurrency('EUR')
      ..setDates(DateTime(2027, 4, 10), DateTime(2027, 4, 12));

    final trip = container.read(tripSettingsProvider);
    expect((trip.passport, trip.currency, trip.nights), ('FR', 'EUR', 2));
  });

  test('search under 2 characters does not call the API', () async {
    expect(await container.read(destinationSearchProvider(' r ').future), isEmpty);
    expect(repo.searches, isEmpty);

    expect(await container.read(destinationSearchProvider('ro').future), [rome]);
    expect(repo.searches, ['ro']);
  });

  test('overview uses the current passport and currency', () async {
    container.read(tripSettingsProvider.notifier)
      ..setPassport('FR')
      ..setCurrency('EUR');

    await container.read(overviewProvider('3169070').future);

    expect(repo.overviewCalls.single, (passport: 'FR', currency: 'EUR'));
  });
}
