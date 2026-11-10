import 'dart:async';

import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/destination/presentation/place_details_screen.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/itinerary/presentation/change_offer_screen.dart';
import 'package:chocomousse/features/itinerary/presentation/widgets/day_view.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'fakes.dart';
import 'plan_app.dart';

void main() {
  group('Itinerary on a phone (I1, I2)', () {
    testWidgets('shows the plan, the trip card and the first day with its notes', (tester) async {
      usePhoneSize(tester, height: 2000);
      final app = PlanApp(tester);
      await app.open('/plans/p1');

      expect(find.text('Rome, 5 days'), findsOneWidget);
      expect(find.text('10 – 14 Apr · 1 adult · Draft, saved'), findsOneWidget);
      expect(find.text('91% match'), findsOneWidget);
      expect(find.text('Your trip'), findsOneWidget);
      expect(find.text(r'$939 · Why 91%?'), findsOneWidget);
      expect(find.text('HOTEL · 4★'), findsOneWidget);
      expect(find.text('Hotel Artemide'), findsOneWidget);
      expect(find.text(r'$612'), findsOneWidget);
      expect(find.text(r'$289'), findsOneWidget);
      expect(find.text('No car'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(5));

      expect(find.text('Day 1 · Rome'), findsOneWidget);
      expect(find.textContaining('45 minutes'), findsOneWidget);
      expect(find.text('Land at FCO, then to the hotel'), findsOneWidget);
      expect(find.text('Arrival · 1h 45'), findsOneWidget);
      expect(find.text('Sight · 2h · 0.4 km walk'), findsOneWidget);
      expect(app.plans.asked, ['plan p1']);
    });

    testWidgets('a day chip shows that day in time order, without the notes', (tester) async {
      usePhoneSize(tester, height: 2000);
      final app = PlanApp(tester);
      await app.open('/plans/p1');

      await app.tapText('Day 2');

      expect(app.location, '/plans/p1?day=2');
      expect(find.text('Day 2 · Colosseum area'), findsOneWidget);
      expect(find.text('Sun 11 Apr · Sunny, 21° / 12° · walking 6.4 km'), findsOneWidget);
      expect(find.text('Sight · 2h · 1.1 km walk from the hotel'), findsOneWidget);
      expect(find.text('Free time'), findsOneWidget);
      expect(find.text('Back at the hotel or wander nearby'), findsOneWidget);
      expect(find.text(r'Event · 2h · 0.4 km walk · from $38'), findsOneWidget);
      expect(find.textContaining('45 minutes'), findsNothing);
      final times = tester.widgetList<TripItemRow>(find.byType(TripItemRow)).map((r) => r.item.start).toList();
      expect(times, ['09:00', '11:15', '13:00', '16:00', '20:00']);
    });

    testWidgets('items open place details, the sight page or the event tickets', (tester) async {
      usePhoneSize(tester, height: 2000);
      final app = PlanApp(tester);
      await app.open('/plans/p1?day=2');

      await app.tapText('Colosseum');
      expect(app.opened, ['https://www.wikidata.org/wiki/Q10285']);

      await app.tapText('Opera at the Baths');
      expect(app.opened.last, 'https://www.ticketmaster.it/e/1');

      await app.tapText('Free time');
      expect(app.location, '/plans/p1?day=2');

      await app.tapText('Roman Forum');
      expect(find.byType(PlaceDetailsScreen), findsOneWidget);
      expect(find.byType(DayCard), findsNothing);
    });

    testWidgets('a plan with no departure city says to choose one', (tester) async {
      usePhoneSize(tester, height: 2000);
      final app = PlanApp(tester, plans: FakePlanRepository(plans: [Plan.fromJson(planJson(withFlight: false))]));
      await app.open('/plans/p1');

      expect(find.text('No flight'), findsOneWidget);
      expect(find.text('Choose where you fly from on Plan your trip to add one'), findsOneWidget);
    });

    testWidgets('warnings show above the day', (tester) async {
      usePhoneSize(tester, height: 2000);
      final plan = Plan.fromJson(planJson(warnings: ["The places couldn't be loaded, so the days were kept."]));
      final app = PlanApp(tester, plans: FakePlanRepository(plans: [plan]));
      await app.open('/plans/p1?day=3');

      expect(find.text("The places couldn't be loaded, so the days were kept."), findsOneWidget);
    });
  });

  group('Why the match and the cost (I3)', () {
    testWidgets('shows the parts, the days fit and the cost lines in a sheet', (tester) async {
      usePhoneSize(tester, height: 2000);
      final app = PlanApp(tester);
      await app.open('/plans/p1');

      await app.tapText(r'$939 · Why 91%?');

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Why 91%'), findsOneWidget);
      expect(find.text('All six'), findsOneWidget);
      expect(find.text('Budget + Comfort'), findsOneWidget);
      expect(find.text('Your days'), findsOneWidget);
      expect(find.text('2 interests'), findsOneWidget);
      expect(find.text('Culture & history 100% · Nature 67%'), findsOneWidget);
      expect(find.text('Hotel · 4 nights'), findsOneWidget);
      expect(find.text('Events · 4'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(
        find.text(r"Not included: 8 items with no known ticket price. Your budget was $1,200, so you're $261 under."),
        findsOneWidget,
      );
    });

    testWidgets('says how far over the budget the plan is', (tester) async {
      usePhoneSize(tester, height: 2000);
      final plan = Plan.fromJson(planJson(overBudgetBy: 40));
      final app = PlanApp(tester, plans: FakePlanRepository(plans: [plan]));
      await app.open('/plans/p1');

      await app.tapText(r'$939 · Why 91%?');

      expect(find.textContaining(r"you're $40 over."), findsOneWidget);
    });
  });

  group('Opening a plan', () {
    testWidgets('shows placeholders, then the error with Try again', (tester) async {
      usePhoneSize(tester);
      final plans = FakePlanRepository()
        ..failWith = DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError);
      final app = PlanApp(tester, plans: plans);
      await app.open('/plans/p1');

      expect(find.text('Cannot reach the TravelGenie server.'), findsOneWidget);
      expect(find.byType(DayPlaceholders), findsOneWidget);

      await app.tapText('Try again');

      expect(find.text('Rome, 5 days'), findsOneWidget);
      expect(plans.asked, ['plan p1', 'plan p1']);
    });

    testWidgets("a plan that isn't the traveller's links to My plans", (tester) async {
      usePhoneSize(tester);
      final app = PlanApp(tester);
      await app.open('/plans/gone');

      expect(find.text("This plan doesn't exist or isn't yours."), findsOneWidget);

      await app.tapText('My plans');
      expect(app.location, '/plans');
    });
  });

  group('Build my plan', () {
    const overview = '/discover/destination/3169070';

    testWidgets('shows placeholder days, then opens the saved plan with the pace', (tester) async {
      usePhoneSize(tester, height: 2400);
      final plans = FakePlanRepository()..gate = Completer<void>();
      final app = PlanApp(tester, plans: plans);
      await app.open(overview);
      app.container.read(tripSettingsProvider.notifier).setPace(Pace.packed);

      final button = find.text('Build my plan');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();
      await tester.pump();

      expect(find.text('Building your plan for Rome…'), findsOneWidget);
      expect(find.byType(DayPlaceholders), findsOneWidget);
      expect(plans.asked, ['build']);

      plans.gate!.complete();
      await tester.pumpAndSettle();

      expect(app.location, '/plans/p2');
      expect(find.text('Rome, 5 days'), findsOneWidget);
      expect(plans.builtWith!.pace, Pace.packed);
      expect(plans.asked, ['build'], reason: 'the built plan opens without asking the API again');
    });

    testWidgets('at 50 plans, says so with a link to My plans', (tester) async {
      usePhoneSize(tester, height: 2400);
      final app = PlanApp(tester, plans: FakePlanRepository()..failWith = const PlanLimitReached());
      await app.open(overview);

      await app.tapText('Build my plan');

      expect(find.text('You can keep up to 50 plans. Delete one to make room.'), findsOneWidget);
      await app.tapText('My plans');
      expect(app.location, '/plans');
    });

    testWidgets('with no places, says so with Back to where it started', (tester) async {
      usePhoneSize(tester, height: 2400);
      final app = PlanApp(tester, plans: FakePlanRepository()..failWith = const NoPlaces('Rome'));
      await app.open(overview);

      await app.tapText('Build my plan');

      expect(
        find.text('No places could be found for Rome right now, so no plan can be made. Try again later.'),
        findsOneWidget,
      );
      await app.tapText('Back');
      expect(app.location, overview);
    });

    testWidgets('a refused value links to Plan your trip', (tester) async {
      usePhoneSize(tester, height: 2400);
      final plans = FakePlanRepository()
        ..failWith = const PlanFieldError('from', 'The trip must start today or later.');
      final app = PlanApp(tester, plans: plans);
      await app.open(overview);

      await app.tapText('Build my plan');

      expect(find.text('The trip must start today or later.'), findsOneWidget);
      await app.tapText('Plan your trip');
      expect(app.location, '$overview/plan');
    });

    testWidgets('a network failure shows Try again, which builds again', (tester) async {
      usePhoneSize(tester, height: 2400);
      final plans = FakePlanRepository()
        ..failWith = DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError);
      final app = PlanApp(tester, plans: plans);
      await app.open(overview);

      await app.tapText('Build my plan');
      expect(find.text('Cannot reach the TravelGenie server.'), findsOneWidget);

      await app.tapText('Try again');
      expect(app.location, '/plans/p2');
      expect(plans.asked, ['build', 'build']);
    });

    testWidgets('a reload of /plans/new opens My plans instead of building again', (tester) async {
      usePhoneSize(tester);
      final app = PlanApp(tester);
      await app.open('/plans/new');

      expect(app.location, '/plans');
      expect(app.plans.asked, isNot(contains('build')));
    });
  });

  group('Change hotel, flight or car (I4)', () {
    testWidgets('lists the kept hotels with the plan one marked, and swapping rebuilds the plan', (tester) async {
      usePhoneSize(tester, height: 2000);
      final app = PlanApp(tester);
      await app.open('/plans/p1');

      await app.tap(find.text('Change').at(1));

      expect(find.byType(ChangeOfferScreen), findsOneWidget);
      expect(find.text('Change hotel'), findsOneWidget);
      expect(find.text('Ranked by your preferences · 2 hotels'), findsOneWidget);
      expect(
        find.text('Choosing a hotel rebuilds the days around it. Same search, so nothing new is searched.'),
        findsOneWidget,
      );
      expect(find.text('HOTEL · 4★ · IN YOUR PLAN'), findsOneWidget);
      expect(find.text('Cheapest, quiet streets'), findsOneWidget);

      await app.tapText('Hotel Santa Maria');

      expect(app.location, '/plans/p1');
      expect(find.text('Hotel Santa Maria'), findsOneWidget);
      expect(app.plans.asked, ['plan p1', 'hotels p1', 'swap p1 hotel bk:2']);
    });

    testWidgets('picking the plan own hotel changes nothing', (tester) async {
      usePhoneSize(tester, height: 2000);
      final app = PlanApp(tester);
      await app.open('/plans/p1/change/hotel');

      await app.tapText('Hotel Artemide');

      expect(app.plans.asked, isNot(contains(startsWith('swap'))));
    });

    testWidgets('adds a car, then removes it', (tester) async {
      usePhoneSize(tester, height: 2000);
      final app = PlanApp(tester);
      await app.open('/plans/p1');

      await app.tapText('Add');
      expect(find.text('Add a car'), findsOneWidget);
      await app.tapText('Fiat 600 · Budget');

      expect(app.location, '/plans/p1');
      expect(find.text('No car'), findsNothing);
      expect(find.text('Fiat 600 · Budget'), findsOneWidget);

      await app.tap(find.text('Change').last);
      expect(find.text('Change car'), findsOneWidget);
      await app.tapText('Remove car');

      expect(find.text('No car'), findsOneWidget);
      expect(app.plans.asked, containsAllInOrder(['swap p1 car bk:car:1', 'remove car p1']));
    });

    testWidgets('a failed swap shows Try again and keeps the plan', (tester) async {
      usePhoneSize(tester, height: 2000);
      final app = PlanApp(tester);
      await app.open('/plans/p1/change/hotel');

      app.plans.failWith = DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError);
      await app.tapText('Hotel Santa Maria');

      expect(find.text('Cannot reach the TravelGenie server.'), findsOneWidget);
      expect(app.plans.saved('p1').hotel!.offer.name, 'Hotel Artemide');

      await app.tapText('Try again');
      expect(app.plans.saved('p1').hotel!.offer.name, 'Hotel Santa Maria');
    });

    testWidgets('a failed list shows Try again', (tester) async {
      usePhoneSize(tester, height: 2000);
      final plans = FakePlanRepository();
      final app = PlanApp(tester, plans: plans);
      await app.open('/plans/p1');
      plans.failWith = DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError);

      await app.tap(find.text('Change').first);

      expect(find.text('Cannot reach the TravelGenie server.'), findsOneWidget);
      await app.tapText('Try again');
      expect(find.text('Change flight'), findsOneWidget);
      expect(find.text('FLIGHT · DIRECT · IN YOUR PLAN'), findsOneWidget);
    });

    testWidgets('opens as a dialog on wide screens', (tester) async {
      useDesktopSize(tester);
      final app = PlanApp(tester);
      await app.open('/plans/p1');

      await app.tap(find.text('Change').at(1));

      expect(find.byType(Dialog), findsOneWidget);
      expect(app.location, '/plans/p1');
      await app.tapText('Hotel Santa Maria');

      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Hotel Santa Maria'), findsOneWidget);
    });
  });

  group('Itinerary on the web (W4)', () {
    testWidgets('lists the days on the left and shows the chosen one on the right', (tester) async {
      useDesktopSize(tester);
      final app = PlanApp(tester);
      await app.open('/plans/p1?day=2');

      expect(find.byType(DayList), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('Day 2 · Sun 11 Apr'), findsOneWidget);
      expect(find.text('Colosseum area'), findsOneWidget);
      expect(find.text('Day 2 · Colosseum area'), findsOneWidget);

      await app.tapText('Day 3 · Mon 12 Apr');
      expect(app.location, '/plans/p1?day=3');

      await app.tapText(r'$939 · Why 91%?');
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Why 91%'), findsOneWidget);
    });
  });
}
