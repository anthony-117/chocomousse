import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/core/links/link_opener.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/hotels/data/hotel_repository.dart';
import 'package:chocomousse/features/hotels/presentation/widgets/hotel_card.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../account/fakes.dart';
import '../destination/fakes.dart';
import '../helpers.dart';
import '../hotels/fakes.dart';

void main() {
  testWidgets('Rome overview → hotels → open a hotel → book → back to the list', (tester) async {
    usePhoneSize(tester, height: 2400);
    final hotels = FakeHotelRepository();
    final opened = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...signedIn(),
          destinationRepositoryProvider.overrideWithValue(FakeDestinationRepository()),
          hotelRepositoryProvider.overrideWithValue(hotels),
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

    await tester.tap(find.text('Rome'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 adults'), findsOneWidget);
    expect(hotels.queries, isEmpty);

    await tester.tap(find.text('See hotels in Rome'));
    await tester.pumpAndSettle();
    expect(find.text('Hotels in Rome'), findsOneWidget);
    expect(hotels.queries, hasLength(1));

    await tester.tap(find.byType(HotelCard));
    await tester.pumpAndSettle();
    expect(hotels.detailQueries.single.hotelId, 'bk:1');

    await tester.tap(find.text('Book on Booking.com'));
    await tester.pump();
    expect(opened, ['https://www.booking.com/hotel/it/artemide.html?checkin=2027-04-10']);

    await tester.tap(find.byTooltip('Back').first);
    await tester.pumpAndSettle();
    expect(find.text('Hotels in Rome'), findsOneWidget);
  });
}
