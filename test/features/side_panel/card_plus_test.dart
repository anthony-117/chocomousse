import 'package:chocomousse/features/chat/application/chat_controller.dart';
import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/chat/presentation/widgets/card_views.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:chocomousse/features/side_panel/presentation/details_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat/fakes.dart';
import 'plan_edits_fixture.dart';

AssistantCard _card(Map<String, Object?> json) => AssistantCard.fromJson(json)!;

/// A chat whose answer has no plan card.
Map<String, Object?> _chatWithoutPlan() => chatJson(
  messages: [
    {'id': '0001', 'role': 'traveller', 'text': 'Hotels in Rome', 'at': '2026-11-10T19:00:00Z'},
    {
      'id': '0002',
      'role': 'assistant',
      'text': 'Here are hotels.',
      'steps': <Object>[],
      'cards': [hotelCardJson()],
      'at': '2026-11-10T19:02:11Z',
    },
  ],
);

Future<PanelFixture> _host(
  WidgetTester tester,
  AssistantCard card, {
  List<Map<String, Object?>>? chats,
  bool planOpen = true,
}) async {
  final fixture = PanelFixture(chats: chats);
  // As in the chat screen, the chat is open while its cards show.
  final view = Consumer(
    builder: (context, ref, _) {
      ref.watch(chatProvider('c1'));
      return Center(
        child: AssistantCardView(card: card, chatKey: 'c1'),
      );
    },
  );
  await fixture.pump(tester, view);
  if (planOpen) {
    fixture.container.read(sidePanelProvider('c1').notifier).openPlan('p1');
    fixture.container.listen(planProvider('p1'), (_, _) {});
  }
  await tester.pumpAndSettle();
  return fixture;
}

String? _note(PanelFixture fixture) => fixture.container.read(chatProvider('c1')).messages.last.text;

void main() {
  testWidgets('"+" on a hotel swaps it into the open plan, opens the Plan pane and notes it', (tester) async {
    final fixture = await _host(tester, _card(hotelCardJson(id: 'bk:2')));
    fixture.container.read(sidePanelProvider('c1').notifier).openPane(PanelPane.trip);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Swap into plan'));
    await tester.pumpAndSettle();
    expect(fixture.plans.asked, contains('swap p1 hotel bk:2'));
    expect(fixture.container.read(sidePanelProvider('c1')).pane, PanelPane.plan);
    expect(_note(fixture), 'Swapped in Hotel Artemide');
    expect(fixture.api.transport.posts, isEmpty);
  });

  testWidgets("without a plan open, the chat's latest plan card is used", (tester) async {
    final fixture = await _host(tester, _card(hotelCardJson()), planOpen: false);
    await tester.tap(find.byTooltip('Swap into plan'));
    await tester.pumpAndSettle();
    expect(fixture.plans.asked, contains('swap p1 hotel bk:1'));
  });

  testWidgets('an offer the plan no longer has asks the assistant instead', (tester) async {
    final fixture = await _host(tester, _card(hotelCardJson()));
    fixture.plans.failWith = const PlanFieldError('offerId', "This offer isn't among the plan's choices any more.");
    await tester.tap(find.byTooltip('Swap into plan'));
    await tester.pumpAndSettle();
    final post = fixture.api.transport.posts.single;
    expect(post.body['text'], 'Swap Hotel Artemide into my plan');
    expect(post.body['about'], {'planId': 'p1'});
  });

  testWidgets('another refusal says why, and asks nothing', (tester) async {
    final fixture = await _host(tester, _card(hotelCardJson()));
    fixture.plans.failWith = const PlanNotFound();
    await tester.tap(find.byTooltip('Swap into plan'));
    await tester.pumpAndSettle();
    expect(find.text("This plan doesn't exist or isn't yours."), findsOneWidget);
    expect(fixture.api.transport.posts, isEmpty);
  });

  testWidgets('without any plan, the assistant builds one with it', (tester) async {
    final fixture = await _host(tester, _card(hotelCardJson()), chats: [_chatWithoutPlan()], planOpen: false);
    await tester.tap(find.byTooltip('Add to plan'));
    await tester.pumpAndSettle();
    expect(fixture.api.transport.posts.single.body['text'], 'Build a plan with Hotel Artemide');
  });

  testWidgets('a car goes into a plan without one as "Add to plan"', (tester) async {
    final fixture = await _host(tester, _card(carCardJson()));
    await tester.tap(find.byTooltip('Add to plan'));
    await tester.pumpAndSettle();
    expect(fixture.plans.asked, contains('swap p1 car bk:car:1'));
    expect(_note(fixture), 'Swapped in Fiat 600');
  });

  testWidgets('places carry no "+"', (tester) async {
    await _host(tester, _card(placeCardJson()));
    expect(find.byTooltip('Swap into plan'), findsNothing);
    expect(find.byTooltip('Add to plan'), findsNothing);
  });

  testWidgets('in Details the same action is a button', (tester) async {
    final fixture = PanelFixture();
    const pane = SizedBox(width: 520, height: 900, child: DetailsPane(chatKey: 'c1'));
    await fixture.pump(tester, pane);
    fixture.container.read(chatProvider('c1'));
    fixture.container.read(sidePanelProvider('c1').notifier)
      ..openPlan('p1')
      ..openCard(_card(carCardJson()));
    fixture.container.listen(planProvider('p1'), (_, _) {});
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add to plan'));
    await tester.pumpAndSettle();
    expect(fixture.plans.asked, contains('swap p1 car bk:car:1'));
  });
}
