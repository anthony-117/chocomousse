import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/hotels/data/hotel_repository.dart';
import 'package:chocomousse/features/ranking/data/ranking_repository.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/ranked_card.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../account/fakes.dart';
import '../destination/fakes.dart';
import '../helpers.dart';
import '../hotels/fakes.dart';
import '../ranking/fakes.dart';

void main() {
  testWidgets('Rome overview → Plan your trip → ranked hotels → why → hotel → back → cars', (tester) async {
    usePhoneSize(tester, height: 2400);
    final ranking = FakeRankingRepository();
    final hotels = FakeHotelRepository();

    await tester.pumpWidget(
      ProviderScope(
        retry: noRetry,
        overrides: [
          ...signedIn(),
          destinationRepositoryProvider.overrideWithValue(FakeDestinationRepository()),
          rankingRepositoryProvider.overrideWithValue(ranking),
          hotelRepositoryProvider.overrideWithValue(hotels),
          pingProvider.overrideWith(
            (ref) async =>
                PingInfo(name: 'pamplemousse', version: '1.0.0', environment: 'Test', utcNow: DateTime.utc(2026)),
          ),
        ],
        child: const TravelGenieApp(),
      ),
    );
    await tester.pumpAndSettle();
    await openShellPlace(tester, 'Explore');

    await tester.tap(find.text('Rome'));
    await tester.pumpAndSettle();
    final entry = find.text('Plan your trip to Rome');
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    expect(ranking.hotelQueries, isEmpty); // the overview ranks nothing

    await tester.tap(entry);
    await tester.pumpAndSettle();
    final find0 = find.text('Find my best plans');
    await tester.ensureVisible(find0);
    await tester.pumpAndSettle();
    await tester.tap(find0);
    await tester.pumpAndSettle();
    expect(find.text('Best for you'), findsOneWidget);
    expect(ranking.hotelQueries, hasLength(1));

    await tester.tap(find.byType(RankedCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open hotel'));
    await tester.pumpAndSettle();
    expect(hotels.detailQueries.single.hotelId, 'bk:1');

    await tester.tap(find.byTooltip('Back').first);
    await tester.pumpAndSettle();
    expect(find.text('Best for you'), findsOneWidget);
    expect(ranking.hotelQueries, hasLength(1));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Cars'));
    await tester.pumpAndSettle();
    expect(find.text('CAR · INTERMEDIATE'), findsOneWidget);
    expect(ranking.carQueries, hasLength(1));
  });
}
