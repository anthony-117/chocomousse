import 'package:chocomousse/features/chat/application/chat_controller.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/presentation/embedded_plan_view.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:chocomousse/features/side_panel/presentation/plan_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';
import '../chat/fakes.dart';
import 'plan_edits_fixture.dart';

Future<PanelFixture> _open(WidgetTester tester, {Size size = desktop, ThemeMode mode = ThemeMode.light}) async {
  final fixture = PanelFixture();
  const pane = SizedBox(width: 520, height: 900, child: PlanPane(chatKey: 'c1'));
  await fixture.pump(tester, pane, size: size, mode: mode);
  fixture.container.read(chatProvider('c1'));
  fixture.container.read(sidePanelProvider('c1').notifier).openPlan('p1');
  await tester.pumpAndSettle();
  return fixture;
}

void main() {
  for (final size in [phone, desktop]) {
    forBothModes('the swap icon asks for alternatives to that item, about it (${size.width.toInt()})', (
      tester,
      mode,
    ) async {
      final fixture = await _open(tester, size: size, mode: mode);
      expect(find.byTooltip('Alternatives to Land at FCO, then to the hotel'), findsNothing, reason: 'no place');
      await tester.tap(find.byTooltip('Alternatives to Trevi Fountain'));
      await tester.pumpAndSettle();
      final post = fixture.api.transport.posts.single;
      expect(post.path, '/assistant/chats/c1/messages');
      expect(post.body['text'], 'Show me alternatives to Trevi Fountain on day 1');
      expect(post.body['about'], {'planId': 'p1', 'day': 1, 'itemId': 'otm:trevi'});
    });
  }

  testWidgets('Ask to change this day sends the text about the day shown', (tester) async {
    final fixture = await _open(tester);
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ask to change this day…'), 'Fewer museums please');
    await tester.tap(find.byTooltip('Ask about this day'));
    await tester.pumpAndSettle();
    final post = fixture.api.transport.posts.single;
    expect(post.body['text'], 'Fewer museums please');
    expect(post.body['about'], {'planId': 'p1', 'day': 2});
  });

  testWidgets('an empty question sends nothing', (tester) async {
    final fixture = await _open(tester);
    await tester.tap(find.byTooltip('Ask about this day'));
    await tester.pumpAndSettle();
    expect(fixture.api.transport.posts, isEmpty);
  });

  testWidgets('an answer that changed the plan reloads it in place, with "Plan updated" for a moment', (tester) async {
    final fixture = await _open(tester);
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    // The assistant swaps the Colosseum on the server, then says so.
    await fixture.plans.addOrReplaceItem('p1', 2, kind: RefKind.place, itemId: 'otm:N123', replaces: 'wd:Q10285');
    fixture.api.transport.reply(
      answerSse(
        last: finalJson(cards: const [], planChanged: 'p1'),
      ),
    );
    await tester.enterText(find.widgetWithText(TextField, 'Ask to change this day…'), 'Swap the Colosseum');
    await tester.tap(find.byTooltip('Ask about this day'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Villa Borghese'), findsOneWidget);
    expect(find.text('Colosseum'), findsNothing);
    expect(find.text('Plan updated'), findsOneWidget);
    expect(find.text('Day 2 · Colosseum area'), findsOneWidget, reason: 'the day shown stays');

    await tester.pump(EmbeddedPlanView.updatedFor + const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Plan updated'), findsNothing);
  });
}
