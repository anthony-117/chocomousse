import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/itinerary/presentation/itinerary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';
import '../../itinerary/fakes.dart';

Future<FakePlanRepository> _pane(
  WidgetTester tester, {
  String id = 'p1',
  Size size = desktop,
  ThemeMode mode = ThemeMode.light,
}) async {
  final plans = FakePlanRepository();
  await pumpApp(
    tester,
    SizedBox(width: 520, child: ItineraryView(planId: id, embedded: true)),
    size: size,
    mode: mode,
    overrides: [planRepositoryProvider.overrideWithValue(plans)],
  );
  await tester.pumpAndSettle();
  return plans;
}

void main() {
  for (final size in [phone, desktop]) {
    forBothModes('shows the header, the three tiles and the six tabs (${size.width.toInt()})', (tester, mode) async {
      await _pane(tester, size: size, mode: mode);
      expect(find.text('Rome, 5 days'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('10 – 14 Apr · 1 adult · from ORY'), findsOneWidget);
      expect(find.text('91%'), findsOneWidget);
      expect(find.text(r'$939'), findsOneWidget);
      expect(find.text(r'of $1,200'), findsOneWidget);
      expect(find.text('Balanced'), findsOneWidget);
      expect(find.text('3 places a day'), findsOneWidget);
      for (final tab in ['Days', 'Hotel', 'Flight', 'Car', 'Map', 'Costs']) {
        expect(find.widgetWithText(Tab, tab), findsOneWidget, reason: tab);
      }
      expect(find.text('Day 2'), findsOneWidget, reason: 'the day chips');
    });
  }

  testWidgets('the tabs show the hotel, the flight and the costs', (tester) async {
    await _pane(tester);
    await tester.tap(find.widgetWithText(Tab, 'Hotel'));
    await tester.pumpAndSettle();
    expect(find.text('Hotel Artemide'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Flight'));
    await tester.pumpAndSettle();
    expect(find.text('ORY → FCO'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Car'));
    await tester.pumpAndSettle();
    expect(find.text('No car in this plan.'), findsOneWidget);
    expect(find.text('Add a car'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Costs'));
    await tester.pumpAndSettle();
    expect(find.text('Cost'), findsOneWidget);
  });

  testWidgets('Mark as planned changes the status, then reads Mark as draft', (tester) async {
    final plans = await _pane(tester);
    await tester.tap(find.text('Mark as planned'));
    await tester.pumpAndSettle();
    expect(plans.calls, contains('status p1 planned'));
    expect(find.text('Planned'), findsOneWidget);
    expect(find.text('Mark as draft'), findsOneWidget);
  });

  testWidgets('a deleted plan says so', (tester) async {
    await _pane(tester, id: 'gone');
    expect(find.text('This plan was deleted.'), findsOneWidget);
  });
}
