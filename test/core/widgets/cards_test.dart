import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/core/widgets/cards/match_pill.dart';
import 'package:chocomousse/core/widgets/cards/media_card.dart';
import 'package:chocomousse/core/widgets/cards/plan_card_tile.dart';
import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/chat/presentation/widgets/card_views.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/ranking/data/ranking_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/chat/fakes.dart';
import '../../features/saved/fakes.dart';
import '../../helpers.dart';
import '../../itinerary/fakes.dart';
import '../../ranking/fakes.dart';

PlanSummary _summary({num? budget = 1200, String id = 'p1'}) {
  final json = planCardJson(id: id);
  final item = {...json['item']! as Map<String, Object?>, 'tripBudget': budget};
  return (AssistantCard.fromJson({...json, 'item': item})! as PlanCard).plan;
}

void main() {
  group('MatchPill', () {
    forBothModes('shows the percent on the success colours, and the reason on tap', (tester, mode) async {
      await pumpApp(tester, Center(child: MatchPill(Match.fromJson(matchJson()))), mode: mode);
      expect(find.text('94% match'), findsOneWidget);
      final palette = mode == ThemeMode.dark ? AppPalette.dark : AppPalette.light;
      final box = tester.widget<Container>(
        find.ancestor(of: find.text('94% match'), matching: find.byType(Container)).first,
      );
      expect((box.decoration! as BoxDecoration).color, palette.statusSuccessSoft);

      await tester.tap(find.text('94% match'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Cheap for Rome, with lots of culture close by'), findsOneWidget);
    });

    testWidgets('shows nothing without a match', (tester) async {
      await pumpApp(tester, const MatchPill(null));
      expect(find.textContaining('match'), findsNothing);
    });
  });

  group('PlanCardTile', () {
    test('the line has the match, the total of the budget and the status', () {
      expect(planCardLine(_summary()), r'Itinerary · 91% match · $939 of $1,200 · Draft');
      expect(planCardLine(_summary(budget: null)), r'Itinerary · 91% match · $939 · Draft');
    });

    for (final size in [phone, desktop]) {
      testWidgets('opens, and shows the open plan with the brand border (${size.width.toInt()})', (tester) async {
        var opened = 0;
        await pumpApp(
          tester,
          PlanCardTile(plan: _summary(), selected: true, onOpen: () => opened++),
          size: size,
          overrides: [planRepositoryProvider.overrideWithValue(FakePlanRepository())],
        );
        expect(find.text('Rome, 5 days'), findsOneWidget);
        await tester.tap(find.text('Open plan'));
        expect(opened, 1);
        final box = tester.widget<Container>(find.byType(Container).first);
        final border = (box.decoration! as BoxDecoration).border! as Border;
        expect(border.top.color, AppPalette.light.brandPrimary);
      });
    }

    testWidgets('a plan found deleted says so and cannot be opened', (tester) async {
      await pumpApp(
        tester,
        Consumer(
          builder: (context, ref, _) {
            ref.watch(planProvider('gone'));
            return PlanCardTile(
              plan: _summary(id: 'gone'),
              onOpen: () {},
            );
          },
        ),
        overrides: [planRepositoryProvider.overrideWithValue(FakePlanRepository())],
      );
      await tester.pumpAndSettle();
      expect(find.text('This plan was deleted'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    });
  });

  group('Flight and hotel cards', () {
    test('a flight reads as a row', () {
      final flight = AssistantCard.fromJson(flightCardJson())! as FlightCard;
      expect(flight.rowTitle, 'ORY → FCO');
      expect(flight.rowSubtitle, 'Sat 10 Apr · 09:25 · Direct · 4 h 20');
      expect(flight.rowPrice, r'$82');
    });

    testWidgets('a hotel is a media card with its match and nightly price', (tester) async {
      final hotel = AssistantCard.fromJson(hotelCardJson())! as HotelCard;
      expect(hotel.subtitle, '4★ · 8.9 · 1.1 km to centre');
      await pumpApp(
        tester,
        Center(
          child: AssistantCardView(card: hotel, chatKey: 'c1'),
        ),
        size: desktop,
        overrides: bookmarkOverrides(FakeSavedRepository()),
      );
      expect(find.byType(MediaCard), findsOneWidget);
      expect(find.text('Hotel Artemide'), findsOneWidget);
      expect(find.text(r'$203 / night'), findsOneWidget);
      expect(find.text('88% match'), findsOneWidget);
    });
  });
}
