import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/core/links/link_opener.dart';
import 'package:chocomousse/features/cars/data/car_repository.dart';
import 'package:chocomousse/features/cars/presentation/widgets/car_card.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../account/fakes.dart';
import '../cars/fakes.dart';
import '../destination/fakes.dart';
import '../helpers.dart';

void main() {
  testWidgets('Rome overview → cars → open a car → Booking.com → back to the list', (tester) async {
    usePhoneSize(tester, height: 2400);
    final cars = FakeCarRepository();
    final opened = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...signedIn(),
          destinationRepositoryProvider.overrideWithValue(FakeDestinationRepository()),
          carRepositoryProvider.overrideWithValue(cars),
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
    expect(find.text('Car rental'), findsOneWidget);
    expect(find.textContaining('city centre · driver 30'), findsOneWidget);
    expect(cars.queries, isEmpty); // the overview makes no car request

    final entry = find.text('See rental cars in Rome');
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.text('Cars in Rome'), findsOneWidget);
    expect(cars.queries, hasLength(1));

    await tester.tap(find.byType(CarCard));
    await tester.pumpAndSettle();
    expect(find.text('Good to know'), findsOneWidget);

    final book = find.text('Search on Booking.com');
    await tester.ensureVisible(book);
    await tester.pumpAndSettle();
    await tester.tap(book);
    await tester.pump();
    expect(opened, [carSearchUrl]);

    await tester.tap(find.byTooltip('Back').first);
    await tester.pumpAndSettle();
    expect(find.text('Cars in Rome'), findsOneWidget);
    expect(cars.queries, hasLength(1));
  });
}
