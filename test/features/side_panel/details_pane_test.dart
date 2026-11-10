import 'dart:async';

import 'package:chocomousse/core/widgets/cards/facts_rows.dart';
import 'package:chocomousse/features/account/application/session.dart';
import 'package:chocomousse/features/cars/presentation/car_details_screen.dart';
import 'package:chocomousse/features/chat/application/chat_trip.dart';
import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/destination/presentation/place_details_screen.dart';
import 'package:chocomousse/features/destination/presentation/widgets/common.dart';
import 'package:chocomousse/features/hotels/data/hotel_repository.dart';
import 'package:chocomousse/features/hotels/presentation/hotel_details_screen.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:chocomousse/features/side_panel/presentation/details_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../account/fakes.dart';
import '../../destination/fakes.dart';
import '../../helpers.dart';
import '../../hotels/fakes.dart';
import '../chat/fakes.dart';

AssistantCard _card(Map<String, Object?> json) => AssistantCard.fromJson(json)!;

class _Pane {
  _Pane({FakeHotelRepository? hotels, FakeDestinationRepository? places})
    : hotels = hotels ?? FakeHotelRepository(),
      places = places ?? FakeDestinationRepository(details: place()),
      transport = FakeChatTransport();

  final FakeHotelRepository hotels;
  final FakeDestinationRepository places;
  final FakeChatTransport transport;
  late ProviderContainer container;

  Future<void> open(
    WidgetTester tester,
    AssistantCard? card, {
    Size size = desktop,
    ThemeMode mode = ThemeMode.light,
    DateTime? now,
    bool settle = true,
  }) async {
    await pumpApp(
      tester,
      SizedBox(
        width: 520,
        child: DetailsPane(chatKey: 'c1', now: now ?? DateTime.utc(2026, 11, 10, 20)),
      ),
      size: size,
      mode: mode,
      overrides: [
        ...chatOverrides(transport, answers: [(200, _chat)]),
        hotelRepositoryProvider.overrideWithValue(hotels),
        destinationRepositoryProvider.overrideWithValue(places),
        plansProvider.overrideWith((ref) => const PlanList(items: [], count: 0, max: 50)),
        profileProvider.overrideWith((ref) => defaultProfile()),
      ],
    );
    container = ProviderScope.containerOf(tester.element(find.byType(DetailsPane)));
    container
        .read(chatTripProvider.notifier)
        .setTrip(ChatTrip(destinationId: '3169070', from: DateTime(2027, 4, 10), to: DateTime(2027, 4, 14), adults: 2));
    if (card != null) container.read(sidePanelProvider('c1').notifier).openCard(card);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }
}

const Map<String, Object?> _chat = {
  'id': 'c1',
  'title': 'Rome',
  'createdAt': '2026-11-09T18:40:00Z',
  'lastMessageAt': '2026-11-10T19:02:11Z',
  'expiresAt': '2027-02-08T19:02:11Z',
  'busy': false,
  'messages': <Object>[],
};

void main() {
  testWidgets('without a card it says what to do', (tester) async {
    await _Pane().open(tester, null);
    expect(find.text('Tap a card in the chat to see it here.'), findsOneWidget);
  });

  for (final size in [phone, desktop]) {
    forBothModes('a hotel opens its details for the chat trip, with the match on top (${size.width.toInt()})', (
      tester,
      mode,
    ) async {
      final pane = _Pane();
      await pane.open(tester, _card(hotelCardJson()), size: size, mode: mode);
      expect(find.byType(HotelDetailsView), findsOneWidget);
      expect(find.text('88% match'), findsOneWidget);
      final query = pane.hotels.detailQueries.last;
      expect(
        (query.hotelId, query.from, query.to, query.adults),
        ('bk:1', DateTime(2027, 4, 10), DateTime(2027, 4, 14), 2),
      );
      expect(find.byTooltip('Back'), findsNothing, reason: 'the panel has its own Close');
    });
  }

  testWidgets('a hotel still loading, then failing, shows Try again', (tester) async {
    final hotels = FakeHotelRepository()..gate = Completer<void>();
    final pane = _Pane(hotels: hotels);
    await pane.open(tester, _card(hotelCardJson()), settle: false);
    expect(find.text('Hotel Artemide'), findsNothing);
    hotels
      ..error = Exception('down')
      ..gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ErrorRetry), findsOneWidget);
  });

  testWidgets('a car opens its details from the card alone', (tester) async {
    await _Pane().open(tester, _card(carCardJson()));
    expect(find.byType(CarDetailsView), findsOneWidget);
    expect(find.text('Search on Booking.com'), findsOneWidget);
    expect(find.textContaining('Driver'), findsNothing, reason: 'a card has no search');
  });

  testWidgets('a flight shows its route, price and that prices are recent', (tester) async {
    await _Pane().open(tester, _card(flightCardJson()));
    expect(find.text('ORY → FCO'), findsOneWidget);
    expect(find.text('Prices are recent, not live'), findsOneWidget);
    expect(find.text('94% match'), findsOneWidget);
  });

  testWidgets('an event offers Get tickets', (tester) async {
    await _Pane().open(tester, _card(eventCardJson()));
    expect(find.text('Jazz at the Baths'), findsOneWidget);
    expect(find.text('Get tickets'), findsOneWidget);
  });

  testWidgets('a place with an OpenTripMap id opens the place details; another a compact view', (tester) async {
    await _Pane().open(tester, _card(placeCardJson(id: 'otm:W3')));
    expect(find.byType(PlaceDetailsView), findsOneWidget);

    await _Pane().open(tester, _card(placeCardJson()));
    expect(find.byType(PlaceDetailsView), findsNothing);
    expect(find.text('Colosseum'), findsOneWidget);
    expect(find.textContaining('41.8900, 12.4900'), findsOneWidget);
  });

  testWidgets('a place view that fails shows Try again', (tester) async {
    await _Pane(places: FakeDestinationRepository()).open(tester, _card(placeCardJson(id: 'otm:W3')));
    expect(find.byType(ErrorRetry), findsOneWidget);
  });

  testWidgets('travel facts show in full', (tester) async {
    await _Pane().open(tester, _card(factsCardJson()));
    expect(find.byType(FactsRows), findsOneWidget);
    expect(find.text('Travel facts · Istanbul'), findsOneWidget);
    expect(find.textContaining('40% chance of rain'), findsOneWidget);
  });

  testWidgets('a card found over a day ago says when, and Search again asks again', (tester) async {
    final pane = _Pane();
    await pane.open(tester, _card(hotelCardJson()), now: DateTime.utc(2026, 11, 12));
    expect(find.text('Found on 10 Nov'), findsOneWidget);
    await tester.tap(find.text('Search again'));
    await tester.pumpAndSettle();
    expect(pane.transport.posts.single.body['text'], 'Search again for Hotel Artemide');
  });

  testWidgets('a fresh card has no Search again', (tester) async {
    await _Pane().open(tester, _card(hotelCardJson()));
    expect(find.text('Search again'), findsNothing);
  });
}
