import 'package:chocomousse/features/destination/data/models.dart';
import 'package:chocomousse/features/destination/presentation/overview_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'fakes.dart';

void main() {
  testWidgets('overview lists events with date, time, venue and price', (tester) async {
    usePhoneSize(tester, height: 2000);
    final repo = FakeDestinationRepository(
      eventsResult: EventsResult(
        items: [
          TravelEvent(
            id: 'tm:E1',
            name: 'AS Roma vs Lazio',
            date: DateTime(2026, 11, 28),
            time: '20:45',
            venue: 'Stadio Olimpico',
            category: 'Sports',
            priceFrom: '45 EUR',
            url: 'https://tm/e1',
          ),
        ],
        warnings: const [],
      ),
    );

    await tester.pumpWidget(host(const OverviewScreen(id: '3169070'), repo));
    await tester.pumpAndSettle();

    expect(find.text('AS Roma vs Lazio'), findsOneWidget);
    expect(find.text('Sat 28 Nov · 20:45 · Stadio Olimpico · from 45 EUR'), findsOneWidget);
  });

  testWidgets('overview says when no events match the dates', (tester) async {
    usePhoneSize(tester, height: 2000);

    await tester.pumpWidget(host(const OverviewScreen(id: '3169070'), FakeDestinationRepository()));
    await tester.pumpAndSettle();

    expect(find.text('No events found for your dates.'), findsOneWidget);
  });
}
