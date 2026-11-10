import 'dart:async';

import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/app/router.dart';
import 'package:chocomousse/core/links/link_opener.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/features/cars/data/car_repository.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/destination/data/models.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/flights/application/flight_providers.dart';
import 'package:chocomousse/features/hotels/data/hotel_repository.dart';
import 'package:chocomousse/features/ranking/data/ranking_repository.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/pace_choice.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/preferences_form.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/ranked_card.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../account/fakes.dart';
import '../cars/fakes.dart';
import '../destination/fakes.dart';
import '../flights/fakes.dart';
import '../helpers.dart';
import '../hotels/fakes.dart';
import 'fakes.dart';

const _plan = '/discover/destination/3169070/plan';

const _paris = DestinationSummary(
  id: '2988507',
  name: 'Paris',
  region: 'Île-de-France',
  countryCode: 'FR',
  countryName: 'France',
  flag: '🇫🇷',
  lat: 48.85,
  lng: 2.35,
  timeZone: 'Europe/Paris',
);

/// The whole app with fake APIs, opened at a location.
class _App {
  _App(this.tester, {FakeRankingRepository? ranking}) : ranking = ranking ?? FakeRankingRepository();

  final WidgetTester tester;
  final FakeRankingRepository ranking;
  final hotels = FakeHotelRepository();
  final opened = <String>[];
  late ProviderContainer container;

  Future<void> open(String location, {bool settle = true}) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: noRetry,
        overrides: [
          ...signedIn(),
          destinationRepositoryProvider.overrideWithValue(FakeDestinationRepository()),
          rankingRepositoryProvider.overrideWithValue(ranking),
          hotelRepositoryProvider.overrideWithValue(hotels),
          carRepositoryProvider.overrideWithValue(FakeCarRepository()),
          linkOpenerProvider.overrideWithValue((url) async {
            opened.add(url);
            return true;
          }),
          pingProvider.overrideWith(
            (ref) async =>
                PingInfo(name: 'pamplemousse', version: '1.0.0', environment: 'Test', utcNow: DateTime.utc(2026)),
          ),
        ],
        child: const TravelGenieApp(),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(tester.element(find.byType(TravelGenieApp)));
    container.read(routerProvider).go(location);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  Preferences get saved => container.read(tripSettingsProvider).preferences;

  /// Moves [criterion]'s slider to its last stop, High.
  Future<void> setHigh(Criterion criterion) async {
    final slider = find.descendant(
      of: find.byWidgetPredicate((w) => w is LevelSlider && w.criterion == criterion),
      matching: find.byType(Slider),
    );
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    final rect = tester.getRect(slider);
    await tester.tapAt(Offset(rect.right - 26, rect.center.dy));
    await tester.pump();
  }

  Future<void> tapText(String text) async {
    final target = find.text(text);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }
}

void main() {
  group('Plan your trip', () {
    testWidgets('keeps a draft until Find my best plans saves it and opens the hotels', (tester) async {
      usePhoneSize(tester, height: 2000);
      final app = _App(tester);
      await app.open(_plan);

      expect(find.text('Plan your trip'), findsOneWidget);
      expect(find.text('Rome, Italy'), findsOneWidget);
      expect(find.text('What matters most?'), findsOneWidget);
      expect(find.byType(LevelSlider), findsNWidgets(6));
      expect(app.ranking.hotelQueries, isEmpty);

      await app.setHigh(Criterion.food);
      expect(app.saved, const Preferences());

      await app.tapText('Find my best plans');
      expect(find.text('Best for you'), findsOneWidget);
      expect(app.saved.of(Criterion.food), Level.high);
      expect(app.ranking.hotelQueries.single.preferences.of(Criterion.food), Level.high);
      expect(app.ranking.carQueries, isEmpty);
    });

    testWidgets('Pace is chosen with the preferences and saved by Find my best plans', (tester) async {
      usePhoneSize(tester, height: 2000);
      final app = _App(tester);
      await app.open(_plan);

      expect(find.byType(PaceChoice), findsOneWidget);
      expect(find.textContaining('3 places a day'), findsOneWidget);

      await app.tapText('Packed');
      expect(find.textContaining('4 places a day'), findsOneWidget);
      expect(app.container.read(tripSettingsProvider).pace, Pace.balanced);

      await app.tapText('Find my best plans');
      expect(app.container.read(tripSettingsProvider).pace, Pace.packed);
    });

    testWidgets('a budget that is not a whole amount above 0 holds the button', (tester) async {
      usePhoneSize(tester, height: 2000);
      final app = _App(tester);
      await app.open(_plan);
      final field = find.widgetWithText(TextField, 'No limit');
      FilledButton button() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Find my best plans'));

      await tester.enterText(field, '0');
      await tester.pump();
      expect(find.text('Enter an amount above 0, or leave it empty.'), findsOneWidget);
      expect(button().onPressed, isNull);

      await tester.enterText(field, '1500');
      await tester.pump();
      expect(button().onPressed, isNotNull);
      await app.tapText('Find my best plans');
      expect(app.saved.tripBudget, 1500);
      expect(app.ranking.hotelQueries.single.preferences.tripBudget, 1500);
    });
  });

  group('Best for you on a phone', () {
    testWidgets('shows ranked hotels, explains one, and opens it', (tester) async {
      usePhoneSize(tester, height: 2000);
      final app = _App(tester);
      await app.open('$_plan/best?tab=hotels');

      expect(find.text('94% match'), findsOneWidget);
      expect(find.text('HOTEL · 4★'), findsOneWidget);
      expect(find.text('Cheap for Rome, with lots of culture close by'), findsOneWidget);
      expect(find.textContaining('Tap a match to see why.'), findsOneWidget);
      expect(find.textContaining('Budget Medium · Culture Medium'), findsOneWidget);

      await tester.tap(find.byType(RankedCard));
      await tester.pumpAndSettle();
      expect(find.text('Why Hotel Artemide'), findsOneWidget);
      expect(find.text('41 sights within 1 km'), findsOneWidget);
      expect(find.text('Not known, counted as average'), findsOneWidget);
      expect(find.text('Each measure is multiplied by how much it matters to you, then averaged.'), findsOneWidget);

      await app.tapText('Open hotel');
      expect(app.hotels.detailQueries.single.hotelId, 'bk:1');
    });

    testWidgets('shows placeholders while it loads', (tester) async {
      usePhoneSize(tester);
      final app = _App(tester)..ranking.gate = Completer<void>();
      await app.open('$_plan/best', settle: false);

      expect(find.byType(RankedCardPlaceholders), findsOneWidget);
      app.ranking.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(RankedCard), findsOneWidget);
    });

    testWidgets('a failure offers Try again above still placeholders', (tester) async {
      usePhoneSize(tester);
      final app = _App(tester)..ranking.error = Exception('down');
      await app.open('$_plan/best');

      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(RankedCardPlaceholders), findsOneWidget);

      app.ranking.error = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(RankedCard), findsOneWidget);
      expect(app.ranking.hotelQueries, hasLength(2));
    });

    testWidgets('no offers says so and links to the booking site', (tester) async {
      usePhoneSize(tester);
      final ranking = FakeRankingRepository(
        hotels: rankedHotels(
          ranked(
            hotelResultsJson(items: [], message: 'Booking.com has nothing left.', searchUrl: 'https://booking.test/s'),
          ),
        ),
      );
      final app = _App(tester, ranking: ranking);
      await app.open('$_plan/best');

      expect(find.text('No hotels for these dates'), findsOneWidget);
      expect(find.text('Booking.com has nothing left.'), findsOneWidget);
      await app.tapText('Search the booking site');
      expect(app.opened, ['https://booking.test/s']);
    });

    testWidgets('unranked offers show the API note and open at once', (tester) async {
      usePhoneSize(tester);
      final ranking = FakeRankingRepository(
        hotels: rankedHotels(ranked(hotelResultsJson(), matches: [null], rankingNote: 'Ranked by price only today.')),
      );
      final app = _App(tester, ranking: ranking);
      await app.open('$_plan/best');

      expect(find.text('Ranked by price only today.'), findsOneWidget);
      expect(find.byType(MatchBadge), findsNothing);
      await tester.tap(find.byType(RankedCard));
      await tester.pumpAndSettle();
      expect(app.hotels.detailQueries.single.hotelId, 'bk:1');
    });

    testWidgets('offers over the whole budget are greyed and explained', (tester) async {
      usePhoneSize(tester);
      final ranking = FakeRankingRepository(
        hotels: rankedHotels(
          ranked(
            hotelResultsJson(),
            matches: [matchJson(percent: 40, overBudget: true, reason: 'Costs more than your whole budget')],
            tripBudget: 500,
          ),
        ),
      );
      final app = _App(tester, ranking: ranking);
      await app.open('$_plan/best');

      expect(tester.widget<MatchBadge>(find.byType(MatchBadge)).overBudget, isTrue);
      expect(
        find.text('Hotels that cost more than your whole budget are listed last, whatever their match.'),
        findsOneWidget,
      );
    });

    testWidgets('flights wait for a departure city, then open the booking link', (tester) async {
      usePhoneSize(tester, height: 2000);
      final app = _App(tester);
      await app.open('$_plan/best?tab=flights');

      expect(find.text('Choose where you fly from to rank flights.'), findsOneWidget);
      expect(app.ranking.flightQueries, isEmpty);
      expect(app.ranking.hotelQueries, isEmpty);

      app.container.read(departureCityProvider.notifier).choose(_paris);
      await tester.pumpAndSettle();
      expect(app.ranking.flightQueries.single.$2, '2988507');
      expect(find.text('FLIGHT · DIRECT'), findsOneWidget);
      expect(find.text('Paris → Rome'), findsOneWidget);
      expect(find.textContaining('Flights are ranked on budget and comfort only'), findsOneWidget);

      await tester.tap(find.byType(RankedCard));
      await tester.pumpAndSettle();
      await app.tapText('Open flight');
      expect(app.opened, [fareJson()['bookingUrl']]);
    });

    testWidgets('only the open tab loads, and a tab seen before shows at once', (tester) async {
      usePhoneSize(tester, height: 2000);
      final app = _App(tester);
      await app.open('$_plan/best');
      expect((app.ranking.hotelQueries.length, app.ranking.carQueries.length), (1, 0));

      await tester.tap(find.widgetWithText(ChoiceChip, 'Cars'));
      await tester.pumpAndSettle();
      expect(find.text('CAR · INTERMEDIATE'), findsOneWidget);
      expect(find.text('See all cars, with sort and filters'), findsOneWidget);
      expect(find.textContaining('City centre, driver 30'), findsOneWidget);
      expect((app.ranking.hotelQueries.length, app.ranking.carQueries.length), (1, 1));

      await tester.tap(find.widgetWithText(ChoiceChip, 'Hotels'));
      await tester.pumpAndSettle();
      expect(find.text('HOTEL · 4★'), findsOneWidget);
      expect(app.ranking.hotelQueries, hasLength(1));
    });

    testWidgets('a car opens its details, and See all cars opens the full list', (tester) async {
      usePhoneSize(tester, height: 2000);
      final app = _App(tester);
      await app.open('$_plan/best?tab=cars');

      await tester.tap(find.byType(RankedCard));
      await tester.pumpAndSettle();
      await app.tapText('Open car');
      expect(find.text('Good to know'), findsOneWidget);

      await tester.tap(find.byTooltip('Back').first);
      await tester.pumpAndSettle();
      await app.tapText('See all cars, with sort and filters');
      expect(find.text('Cars in Rome'), findsOneWidget);
    });

    testWidgets('Edit goes back to the same tab with the new ranking', (tester) async {
      usePhoneSize(tester, height: 2000);
      final app = _App(tester);
      await app.open('$_plan/best?tab=cars');

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Plan your trip'), findsOneWidget);

      await app.setHigh(Criterion.comfort);
      await app.tapText('Find my best plans');
      expect(find.text('Best for you'), findsOneWidget);
      expect(find.text('CAR · INTERMEDIATE'), findsOneWidget);
      expect(find.textContaining('Comfort High'), findsOneWidget);
      expect(app.ranking.carQueries.map((q) => q.preferences.of(Criterion.comfort)), [Level.medium, Level.high]);
      expect(app.ranking.hotelQueries, isEmpty);
    });
  });

  group('Best for you on a wide screen', () {
    void useWide(WidgetTester tester) {
      tester.view
        ..physicalSize = const Size(1400, 1600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('shows the form, the list and why the selected offer ranks', (tester) async {
      useWide(tester);
      final app = _App(tester);
      await app.open('$_plan/best');

      expect(find.byType(PreferencesForm), findsOneWidget);
      expect(find.text('Why Hotel Artemide · 94%'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(
        find.text("The ranking updates as you move a slider; prices don't change and no new search runs."),
        findsOneWidget,
      );
    });

    testWidgets('slider moves save once they settle, and none is lost', (tester) async {
      useWide(tester);
      final app = _App(tester);
      await app.open('$_plan/best');

      await app.setHigh(Criterion.food);
      await tester.pump(const Duration(milliseconds: 200));
      await app.setHigh(Criterion.nature);
      await tester.pump(const Duration(milliseconds: 300));
      expect(app.saved, const Preferences());
      expect(app.ranking.hotelQueries, hasLength(1));

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect((app.saved.of(Criterion.food), app.saved.of(Criterion.nature)), (Level.high, Level.high));
      expect(app.ranking.hotelQueries, hasLength(2));
    });
  });
}
