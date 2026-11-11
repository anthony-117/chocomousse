import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/hotels/data/hotel_repository.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/itinerary/presentation/my_plans_screen.dart';
import 'package:chocomousse/features/ranking/data/ranking_repository.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../account/fakes.dart';
import '../destination/fakes.dart';
import '../helpers.dart';
import '../hotels/fakes.dart';
import '../itinerary/fakes.dart';
import '../ranking/fakes.dart';

void main() {
  testWidgets('Plan your trip with Pace → Best for you → Build my plan → change hotel → My plans → rename → delete', (
    tester,
  ) async {
    usePhoneSize(tester, height: 2400);
    final plans = FakePlanRepository(plans: []);

    await tester.pumpWidget(
      ProviderScope(
        retry: noRetry,
        overrides: [
          ...signedIn(),
          destinationRepositoryProvider.overrideWithValue(FakeDestinationRepository()),
          rankingRepositoryProvider.overrideWithValue(FakeRankingRepository()),
          hotelRepositoryProvider.overrideWithValue(FakeHotelRepository()),
          planRepositoryProvider.overrideWithValue(plans),
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

    Future<void> tap(Finder target) async {
      await tester.ensureVisible(target.first);
      await tester.pumpAndSettle();
      await tester.tap(target.first);
      await tester.pumpAndSettle();
    }

    await tap(find.text('Rome'));
    await tap(find.text('Plan your trip to Rome'));
    await tap(find.text('Relaxed'));
    await tap(find.text('Find my best plans'));
    expect(find.text('Best for you'), findsOneWidget);

    await tap(find.text('Build my plan'));
    expect(find.text('Rome, 5 days'), findsOneWidget);
    expect(plans.builtWith!.pace, Pace.relaxed);

    expect(find.text('No flight'), findsOneWidget);
    await tap(find.text('Change'));
    await tap(find.text('Hotel Santa Maria'));
    expect(find.text('Hotel Santa Maria'), findsOneWidget);

    await tap(find.byTooltip('Back'));
    expect(find.byType(PlanCard), findsOneWidget);
    expect(find.text('1 of 50 plans'), findsOneWidget);

    await tap(find.byTooltip('Plan actions'));
    await tap(find.text('Rename'));
    await tester.enterText(find.byType(TextField), 'Spring in Rome');
    await tap(find.text('Save'));
    expect(find.text('Spring in Rome'), findsOneWidget);

    await tap(find.byTooltip('Plan actions'));
    await tap(find.text('Delete plan'));
    await tap(find.text('Delete'));
    expect(find.text('No plans yet'), findsOneWidget);
    expect(plans.asked, ['build', 'hotels p2', 'swap p2 hotel bk:2', 'rename p2 Spring in Rome', 'delete p2']);
  });
}
