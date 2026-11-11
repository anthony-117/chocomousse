import 'package:chocomousse/core/widgets/cards/facts_rows.dart';
import 'package:chocomousse/core/widgets/cards/media_card.dart';
import 'package:chocomousse/core/widgets/cards/pin_preview.dart';
import 'package:chocomousse/core/widgets/cards/result_row.dart';
import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/chat/presentation/widgets/card_views.dart';
import 'package:chocomousse/features/destination/data/models.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/chat/fakes.dart';
import '../../helpers.dart';

T _card<T extends AssistantCard>(Map<String, Object?> json) => AssistantCard.fromJson(json)! as T;

const _pins = [
  MapPin(id: 'a', lat: 41.90, lng: 12.48, kind: PinKind.hotel, label: 'Hotel'),
  MapPin(id: 'b', lat: 41.88, lng: 12.50, kind: PinKind.place, label: 'Sight', approximate: true),
];

void main() {
  group('Place, event and car cards', () {
    test('their lines', () {
      final place = _card<PlaceCard>(placeCardJson());
      expect(place.subtitle, 'Sight · ★ 4.7');
      final event = _card<EventCard>(eventCardJson());
      expect(event.subtitle, 'Sun 11 Apr · 21:00 · Terme di Caracalla');
      final car = _card<CarCard>(carCardJson());
      expect(car.rowTitle, 'Fiat 600 · Budget');
      expect(
        car.rowSubtitle(from: DateTime(2027, 4, 10), to: DateTime(2027, 4, 14)),
        'Pick-up via Sardegna · 10 – 14 Apr',
      );
      expect(car.rowSubtitle(), 'Pick-up via Sardegna');
      expect(car.rowPrice, r'$77');
    });

    test('a place reads its kind', () {
      Place of(PlaceCategory category, String? kind) =>
          Place.fromJson({...placeItemJson(), 'category': category.name, 'kind': kind});
      expect(placeKindLabel(of(PlaceCategory.restaurant, 'Trattoria')), 'Restaurant');
      expect(placeKindLabel(of(PlaceCategory.attraction, 'Gardens and parks')), 'Nature');
      expect(placeKindLabel(of(PlaceCategory.attraction, 'Night clubs')), 'Nightlife');
      expect(placeKindLabel(of(PlaceCategory.attraction, null)), 'Sight');
    });

    for (final size in [phone, desktop]) {
      forBothModes('places and events are media cards; cars are rows (${size.width.toInt()})', (tester, mode) async {
        await pumpApp(
          tester,
          ListView(
            children: [
              Center(
                child: AssistantCardView(card: _card(placeCardJson()), chatKey: 'c1'),
              ),
              Center(
                child: AssistantCardView(card: _card(eventCardJson()), chatKey: 'c1'),
              ),
              AssistantCardView(card: _card(carCardJson()), chatKey: 'c1'),
            ],
          ),
          size: size,
          mode: mode,
          overrides: [
            ...chatOverrides(FakeChatTransport()),
            plansProvider.overrideWith((ref) => const PlanList(items: [], count: 0, max: 50)),
          ],
        );
        await tester.pumpAndSettle();
        expect(find.byType(MediaCard), findsNWidgets(2));
        expect(find.byType(ResultRow), findsOneWidget);
        expect(find.text('Jazz at the Baths'), findsOneWidget);
        expect(find.text('Fiat 600 · Budget'), findsOneWidget);
      });
    }
  });

  group('FactsRows', () {
    test('a missing part is left out', () {
      final facts = _card<FactsCard>(factsCardJson()).facts;
      final lines = factsLines(facts);
      expect(lines.map((l) => l.$2), ['Weather', 'Visa', 'Currency', 'Safety', 'Holidays']);
      expect(lines.first.$3, '21° / 13° · Mild, some rain');
      expect(lines[2].$3, '1 USD = 34.10 TRY');
      expect(lines.last.$3, '1 May · Labour Day');

      final bare = _card<FactsCard>({
        ...factsCardJson(),
        'item': {
          'destination': {'id': '1', 'name': 'Rome'},
          'holidays': <Object>[],
        },
      }).facts;
      expect(factsLines(bare), isEmpty);
    });

    testWidgets('shows "+n more" holidays', (tester) async {
      final json = factsCardJson();
      final item = {
        ...json['item']! as Map<String, Object?>,
        'holidays': [
          {'date': '2027-05-01', 'name': 'Labour Day'},
          {'date': '2027-05-19', 'name': 'Youth Day'},
        ],
      };
      await pumpApp(tester, FactsRows(facts: _card<FactsCard>({...json, 'item': item}).facts));
      expect(find.text('1 May · Labour Day +1 more'), findsOneWidget);
    });
  });

  group('PinPreview', () {
    test('projects the corners of the padded box', () {
      final bounds = PinBounds.of(_pins);
      const size = Size(200, 100);
      final west = bounds.project(41.89, bounds.minLng, size);
      final north = bounds.project(bounds.maxLat, 12.49, size);
      expect(west.dx, closeTo(0, 0.001));
      expect(north.dy, closeTo(0, 0.001));
      final a = bounds.project(41.90, 12.48, size);
      final b = bounds.project(41.88, 12.50, size);
      expect(a.dx < b.dx && a.dy < b.dy, isTrue, reason: 'north-west, then south-east');
      expect(a.dx, closeTo(200 * 0.12 / 1.24, 0.01));
    });

    test('a single pin still gets a 0.01° box', () {
      final bounds = PinBounds.of([_pins.first]);
      expect(bounds.maxLat - bounds.minLat, closeTo(0.01 * 1.24, 1e-9));
    });

    testWidgets('a tap on a pin or a row selects it; approximate pins have a legend', (tester) async {
      final chosen = <String>[];
      await pumpApp(
        tester,
        SingleChildScrollView(
          child: PinPreview(pins: _pins, onSelect: chosen.add),
        ),
        size: desktop,
      );
      expect(find.text('Some places show the city centre'), findsOneWidget);
      await tester.tap(find.text('Sight'));
      expect(chosen, ['b']);

      final box = tester.getRect(find.byType(CustomPaint).last);
      final at = PinBounds.of(_pins).project(41.90, 12.48, box.size);
      await tester.tapAt(box.topLeft + at);
      expect(chosen, ['b', 'a']);
    });
  });

  test('See all opens the list of its kind for the chat city', () {
    String? route(Map<String, Object?> json, [String? id = '1']) => seeAllRoute([_card(json)], id);
    expect(route(hotelCardJson()), '/discover/destination/1/hotels');
    expect(route(flightCardJson()), '/discover/destination/1/flights');
    expect(route(carCardJson()), '/discover/destination/1/cars');
    expect(route(placeCardJson()), '/discover/destination/1/places?category=attraction');
    expect(route(eventCardJson()), '/discover/destination/1');
    expect(route(planCardJson()), isNull);
    expect(route(factsCardJson()), isNull);
    expect(route(hotelCardJson(), null), isNull, reason: 'no city yet');
    expect(seeAllRoute(const [], '1'), isNull);
  });
}
