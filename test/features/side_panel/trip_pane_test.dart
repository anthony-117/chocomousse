import 'dart:async';

import 'package:chocomousse/features/chat/application/chat_controller.dart';
import 'package:chocomousse/features/chat/application/chat_trip.dart';
import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/chat/presentation/widgets/card_views.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:chocomousse/features/side_panel/presentation/trip_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';
import '../chat/fakes.dart';
import 'plan_edits_fixture.dart';

Map<String, Object?> _chat() => chatJson(
  messages: [
    {'id': '0001', 'role': 'traveller', 'text': 'Plan Rome', 'at': '2026-11-10T19:00:00Z'},
    {
      'id': '0002',
      'role': 'assistant',
      'text': 'Here is a 5-day plan.',
      'steps': [
        stepJson(tool: 'search_hotels', summary: 'Searched hotels', total: 48, cards: [hotelCardJson()]),
      ],
      'cards': [planCardJson(), hotelCardJson()],
      'at': '2026-11-10T19:02:11Z',
    },
  ],
);

Future<PanelFixture> _open(
  WidgetTester tester, {
  bool planOpen = true,
  Size size = desktop,
  ThemeMode mode = ThemeMode.light,
}) async {
  tester.view.physicalSize = Size(size.width, 2000);
  final fixture = PanelFixture(chats: [_chat()]);
  final pane = Consumer(
    builder: (context, ref, _) {
      ref.watch(chatProvider('c1'));
      return const SizedBox(width: 520, child: TripPane(chatKey: 'c1'));
    },
  );
  await fixture.pump(tester, pane, size: Size(size.width, 2000), mode: mode);
  if (planOpen) fixture.container.read(sidePanelProvider('c1').notifier).openPlan('p1');
  await tester.pumpAndSettle();
  return fixture;
}

void main() {
  for (final size in [phone, desktop]) {
    forBothModes('edits go to the chips the next messages use (${size.width.toInt()})', (tester, mode) async {
      final fixture = await _open(tester, size: size, mode: mode);
      await tester.tap(find.byTooltip('More adults'));
      await tester.pump();
      await tester.tap(find.text('Relaxed'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Trip budget'), '1500');
      await tester.pump();
      final chips = fixture.container.read(chatTripProvider);
      expect(chips.trip.adults, 2);
      expect((chips.pace, chips.paceChanged), (Pace.relaxed, true));
      expect(chips.trip.tripBudget, 1500);
      expect(find.text('2'), findsOneWidget);
    });
  }

  testWidgets('Rebuild plan rebuilds the open plan with the values, then opens it', (tester) async {
    final fixture = await _open(tester);
    await tester.tap(find.text('Relaxed'));
    await tester.pump();
    fixture.plans.gate = Completer<void>();
    await tester.tap(find.text('Rebuild plan'));
    await tester.pump();
    expect(find.text('Rebuilding…'), findsOneWidget);
    fixture.plans.gate!.complete();
    fixture.plans.gate = null;
    await tester.pumpAndSettle();
    expect(fixture.plans.asked, contains('rebuild p1'));
    expect(fixture.plans.rebuiltWith?.pace, Pace.relaxed);
    expect(fixture.container.read(sidePanelProvider('c1')).pane, PanelPane.plan);
  });

  testWidgets('a rebuild that fails says why and leaves the plan', (tester) async {
    final fixture = await _open(tester);
    fixture.plans.failWith = const NoPlaces('Rome');
    await tester.tap(find.text('Rebuild plan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No places could be found for Rome'), findsOneWidget);
    expect(find.text('Rebuild plan'), findsOneWidget);
  });

  testWidgets('without an open plan Rebuild waits for one', (tester) async {
    await _open(tester, planOpen: false);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Rebuild plan')).onPressed, isNull);
    expect(find.text('Open a plan to rebuild it with these values.'), findsOneWidget);
  });

  testWidgets('This chat lists its plans and what it found; each opens its pane', (tester) async {
    final fixture = await _open(tester, planOpen: false);
    expect(find.text('THIS CHAT'), findsOneWidget);
    expect(find.text('Rome, 5 days'), findsOneWidget);
    await tester.tap(find.text('Hotels · 48'));
    await tester.pump();
    final panel = fixture.container.read(sidePanelProvider('c1'));
    expect((panel.pane, panel.selected?.id), (PanelPane.details, 'bk:1'));

    await tester.tap(find.text('Open plan'));
    await tester.pump();
    expect(fixture.container.read(sidePanelProvider('c1')).planId, 'p1');
  });

  test('foundByKind keeps the most a step found, or the cards shown', () {
    final hotel = AssistantCard.fromJson(hotelCardJson())!;
    final place = AssistantCard.fromJson(placeCardJson())!;
    final found = foundByKind(
      [hotel, place],
      [
        (cards: [hotel], total: 48),
        (cards: [hotel], total: 12),
      ],
    );
    expect(found.map((f) => (f.$1, f.$2)), [(CardKind.hotel, 48), (CardKind.place, 1)]);
  });
}
