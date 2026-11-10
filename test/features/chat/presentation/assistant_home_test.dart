import 'dart:async';

import 'package:chocomousse/core/widgets/cards/plan_card_tile.dart';
import 'package:chocomousse/core/widgets/skeleton.dart';
import 'package:chocomousse/features/account/application/session.dart';
import 'package:chocomousse/features/chat/presentation/assistant_home.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../../account/fakes.dart';
import '../../../helpers.dart';
import '../../../itinerary/fakes.dart';
import '../fakes.dart';

PlanList _list(int n) => PlanList(
  items: [for (var i = 1; i <= n; i++) PlanSummary.fromJson(summaryJson(id: 'p$i', name: 'Trip $i'))],
  count: n,
  max: 50,
);

Future<void> _home(
  WidgetTester tester, {
  Size size = desktop,
  ThemeMode mode = ThemeMode.light,
  Future<PlanList> Function()? plans,
  String name = 'Sam Haddad',
}) async {
  final overrides = <Override>[
    ...chatOverrides(FakeChatTransport()),
    plansProvider.overrideWith((ref) => plans?.call() ?? Future.value(_list(0))),
    profileProvider.overrideWith((ref) => defaultProfile(displayName: name)),
    planRepositoryProvider.overrideWithValue(FakePlanRepository()),
  ];
  await pumpApp(tester, const AssistantHome(), size: size, mode: mode, overrides: overrides);
  await tester.pump();
}

void main() {
  test('the greeting uses the first name', () {
    expect(homeGreeting('Sam Haddad'), 'Where to next, Sam?');
    expect(homeGreeting(''), 'Where to next?');
    expect(homeGreeting(null), 'Where to next?');
  });

  forBothModes('wide: the greeting, the composer and seven suggestions', (tester, mode) async {
    await _home(tester, mode: mode);
    await tester.pumpAndSettle();
    expect(find.text('Where to next, Sam?'), findsOneWidget);
    expect(find.byType(ActionChip), findsNWidgets(7));
    expect(find.text('My preferences'), findsOneWidget);
    expect(
      find.text('TravelGenie checks prices with live sources. Prices can change before you book.'),
      findsOneWidget,
    );
  });

  forBothModes('phone: the line under the greeting and four suggestion cards', (tester, mode) async {
    await _home(tester, size: phone, mode: mode);
    await tester.pumpAndSettle();
    expect(
      find.text("Plan a trip, find flights, hotels and cars, or ask anything about where you're going."),
      findsOneWidget,
    );
    expect(find.byType(ActionChip), findsNothing);
    expect(find.text('Plan 5 days in Rome'), findsOneWidget);
    expect(find.text('Top sights in Paris'), findsNothing, reason: 'only the first four');
    expect(find.text('My preferences'), findsNothing);
  });

  group('Pick up where you left off', () {
    testWidgets('shows a skeleton while loading', (tester) async {
      await _home(tester, plans: () => Completer<PlanList>().future);
      expect(find.text('Pick up where you left off'), findsOneWidget);
      expect(find.byType(SkeletonBox), findsWidgets);
    });

    testWidgets('shows the two latest plans and All plans', (tester) async {
      await _home(tester, plans: () async => _list(3));
      await tester.pumpAndSettle();
      expect(find.byType(PlanCardTile), findsNWidgets(2));
      expect(find.text('Trip 1'), findsOneWidget);
      expect(find.text('Trip 3'), findsNothing);
      expect(find.text('All plans'), findsOneWidget);
    });

    testWidgets('is hidden without plans', (tester) async {
      await _home(tester);
      await tester.pumpAndSettle();
      expect(find.text('Pick up where you left off'), findsNothing);
    });

    testWidgets('a failure offers Try again', (tester) async {
      var failing = true;
      await _home(tester, plans: () => failing ? Future.error(Exception('down')) : Future.value(_list(1)));
      await tester.pump();
      await tester.pump();
      expect(find.text('Try again'), findsOneWidget);

      failing = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(PlanCardTile), findsOneWidget);
    });
  });
}
