import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/app/router.dart';
import 'package:chocomousse/core/links/link_opener.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../account/fakes.dart';
import '../destination/fakes.dart';
import 'fakes.dart';

/// The whole app with a fake plan API, opened at a location.
class PlanApp {
  PlanApp(this.tester, {FakePlanRepository? plans}) : plans = plans ?? FakePlanRepository();

  final WidgetTester tester;
  final FakePlanRepository plans;
  final opened = <String>[];
  late ProviderContainer container;

  String get location => container.read(routerProvider).routerDelegate.currentConfiguration.uri.toString();

  Future<void> open(String location) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: noRetry,
        overrides: [
          ...signedIn(),
          destinationRepositoryProvider.overrideWithValue(FakeDestinationRepository()),
          planRepositoryProvider.overrideWithValue(plans),
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
    container = ProviderScope.containerOf(tester.element(find.byType(TravelGenieApp)));
    container.read(routerProvider).go(location);
    await tester.pumpAndSettle();
  }

  Future<void> tap(Finder target) async {
    await tester.ensureVisible(target.first);
    await tester.pumpAndSettle();
    await tester.tap(target.first);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(String text) => tap(find.text(text));
}

void useDesktopSize(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1440, 1400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
