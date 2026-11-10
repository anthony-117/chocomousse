import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/app/router.dart';
import 'package:chocomousse/features/chat/application/chat_trip.dart';
import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/chat/presentation/widgets/chat_bits.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/hotels/data/hotel_repository.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/side_panel/presentation/details_pane.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../account/fakes.dart';
import '../destination/fakes.dart';
import '../features/chat/fakes.dart';
import '../hotels/fakes.dart';
import '../itinerary/fakes.dart';

/// One question for each card kind: (what is asked, the tool, the card, its group label, the text to tap, what
/// Details shows).
final List<(String, String, Map<String, Object?>, String, String, String)> _asks = [
  (
    'Flights to Rome in April',
    'search_flights',
    flightCardJson(),
    'FLIGHTS',
    'ORY → FCO',
    'Prices are recent, not live',
  ),
  ('Hotels in Rome', 'search_hotels', hotelCardJson(), 'HOTELS', 'Hotel Artemide', 'Hotel Artemide'),
  ('A car in Rome', 'search_cars', carCardJson(), 'CARS', 'Fiat 600 · Budget', 'Search on Booking.com'),
  ('What to see in Rome', 'list_places', placeCardJson(), 'PLACES', 'Colosseum', '41.8900, 12.4900'),
  ('Concerts in Rome', 'list_events', eventCardJson(), 'EVENTS', 'Jazz at the Baths', 'Get tickets'),
  (
    'Do I need a visa for Turkey?',
    'get_overview',
    factsCardJson(),
    'TRAVEL FACTS',
    'Weather',
    'Travel facts · Istanbul',
  ),
];

String _answer(int i, String tool, Map<String, Object?> card) => [
  if (i == 0) sse('chat', {'chatId': 'c9', 'title': 'Rome', 'messageId': '0001'}),
  sse('step', stepJson(tool: tool, summary: 'Step $i', total: 40, cards: [card])),
  sse(
    'final',
    finalJson(messageId: '${i + 2}'.padLeft(4, '0'), text: 'Answer $i.', cards: [card], suggestions: const []),
  ),
].join();

void main() {
  testWidgets('any one thing: each card kind shows, opens in Details, and See all opens the list for the chat trip', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1440, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final hotels = FakeHotelRepository();
    final transport = FakeChatTransport([for (final (i, a) in _asks.indexed) _answer(i, a.$2, a.$3)]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...signedIn(),
          ...chatOverrides(transport),
          planRepositoryProvider.overrideWithValue(FakePlanRepository()),
          hotelRepositoryProvider.overrideWithValue(hotels),
          destinationRepositoryProvider.overrideWithValue(FakeDestinationRepository(details: place())),
          pingProvider.overrideWith(
            (ref) async =>
                PingInfo(name: 'pamplemousse', version: '1.0.0', environment: 'Test', utcNow: DateTime.utc(2026)),
          ),
        ],
        child: const TravelGenieApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(TravelGenieApp)));
    final router = container.read(routerProvider);
    container
        .read(chatTripProvider.notifier)
        .setTrip(ChatTrip(destinationId: '3169070', from: DateTime(2027, 4, 10), to: DateTime(2027, 4, 14), adults: 2));
    await tester.pumpAndSettle();

    for (final (i, (ask, _, _, label, tap, detail)) in _asks.indexed) {
      await tester.enterText(find.byType(TextField).last, ask);
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/chat/c9');
      expect(find.text('Answer $i.'), findsOneWidget);
      expect(find.text(label), findsOneWidget, reason: ask);

      await tester.tap(find.text(tap).last);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(DetailsPane), matching: find.textContaining(detail)),
        findsWidgets,
        reason: 'Details for $ask',
      );
    }
    expect(transport.posts, hasLength(6));

    final hotelsGroup = find.ancestor(of: find.text('HOTELS'), matching: find.byType(CardGroup));
    await tester.scrollUntilVisible(find.text('HOTELS'), -300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: hotelsGroup, matching: find.text('See all 40')));
    await tester.pumpAndSettle();
    expect(find.text('Hotels in Rome'), findsOneWidget);
    final query = hotels.queries.last;
    expect(
      (query.destinationId, query.from, query.to, query.adults),
      ('3169070', DateTime(2027, 4, 10), DateTime(2027, 4, 14), 2),
    );
  });
}
