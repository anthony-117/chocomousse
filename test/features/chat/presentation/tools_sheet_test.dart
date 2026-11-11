import 'package:chocomousse/features/account/application/session.dart';
import 'package:chocomousse/features/chat/application/chat_trip.dart';
import 'package:chocomousse/features/chat/application/tool_starters.dart';
import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/chat/presentation/composer.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../../account/fakes.dart';
import '../../../helpers.dart';
import '../../../itinerary/fakes.dart';
import '../fakes.dart';

List<Override> _overrides({int plans = 7}) => [
  ...chatOverrides(FakeChatTransport()),
  plansProvider.overrideWith(
    (ref) => PlanList(
      items: [for (var i = 1; i <= plans; i++) PlanSummary.fromJson(summaryJson(id: 'p$i', name: 'Plan $i'))],
      count: plans,
      max: 50,
    ),
  ),
  profileProvider.overrideWith((ref) => defaultProfile()),
  planRepositoryProvider.overrideWithValue(FakePlanRepository()),
];

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(Composer)));

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('390 px (${mode.name}): the sheet has the eight tools, the two rows, no attach and no location', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Composer(onSend: (_) {}),
        mode: mode,
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tools, trip and plans'));
      await tester.pumpAndSettle();

      expect(find.text('What can I help with?'), findsOneWidget);
      expect(find.text("Pick one, or just type — I'll use the right tool."), findsOneWidget);
      for (final tool in Tool.values) {
        expect(find.bySemanticsLabel('${tool.label}, ${tool.detail}'), findsOneWidget);
      }
      expect(find.text('Set trip dates and travellers'), findsOneWidget);
      expect(find.text('Open a saved plan'), findsOneWidget);
      expect(find.textContaining('Attach'), findsNothing);
      expect(find.textContaining('location'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a tool fills the composer with its starter and sends nothing', (tester) async {
    // The trip chip starts from the latest plan (Rome, 10 – 14 Apr); the traveller can change it.
    final sent = <String>[];
    await pumpApp(tester, Composer(onSend: sent.add), overrides: _overrides());
    await tester.pumpAndSettle();
    _container(tester)
        .read(chatTripProvider.notifier)
        .setTrip(ChatTrip(destinationName: 'Rome', from: DateTime(2027, 4, 10), to: DateTime(2027, 4, 14)));

    await tester.tap(find.byTooltip('Tools, trip and plans'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Hotels, Ranked for you'));
    await tester.pumpAndSettle();

    expect(find.text('What can I help with?'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Find hotels in Rome for 10 – 14 Apr');
    expect(sent, isEmpty);
  });

  testWidgets('a given controller receives the starter', (tester) async {
    final text = TextEditingController();
    addTearDown(text.dispose);
    await pumpApp(
      tester,
      Composer(onSend: (_) {}, controller: text),
      overrides: _overrides(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tools, trip and plans'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Places, Sights & food'));
    await tester.pumpAndSettle();
    expect(text.text, 'Top sights in Rome');
  });

  testWidgets('My preferences opens the preferences instead of a starter', (tester) async {
    await pumpApp(tester, Composer(onSend: (_) {}), overrides: _overrides());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tools, trip and plans'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('My preferences, Budget & pace'));
    await tester.pumpAndSettle();
    expect(find.text('Used for the next messages of this chat.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });

  testWidgets('Set trip dates and travellers opens the trip editor', (tester) async {
    await pumpApp(tester, Composer(onSend: (_) {}), overrides: _overrides());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tools, trip and plans'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set trip dates and travellers'));
    await tester.pumpAndSettle();
    expect(find.text('Your trip'), findsOneWidget);
  });

  testWidgets('Open a saved plan lists the latest five and opens one in the panel', (tester) async {
    await pumpApp(
      tester,
      Composer(onSend: (_) {}, panelKey: 'c1'),
      size: const Size(390, 1400),
      overrides: _overrides(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tools, trip and plans'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open a saved plan'));
    await tester.pumpAndSettle();
    expect(find.text('Plan 5'), findsOneWidget);
    expect(find.text('Plan 6'), findsNothing);

    await tester.tap(find.text('Plan 2'));
    await tester.pumpAndSettle();
    final panel = _container(tester).read(sidePanelProvider('c1'));
    expect((panel.open, panel.pane, panel.planId), (true, PanelPane.plan, 'p2'));
  });

  testWidgets('without plans there is no saved-plan row', (tester) async {
    await pumpApp(tester, Composer(onSend: (_) {}), overrides: _overrides(plans: 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tools, trip and plans'));
    await tester.pumpAndSettle();
    expect(find.text('Open a saved plan'), findsNothing);
  });

  testWidgets('1440 px: "+" opens the same entries as a menu', (tester) async {
    final sent = <String>[];
    await pumpApp(
      tester,
      Composer(onSend: sent.add),
      size: desktop,
      overrides: _overrides(plans: 2),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tools, trip and plans'));
    await tester.pumpAndSettle();

    expect(find.text('What can I help with?'), findsNothing);
    for (final tool in Tool.values) {
      expect(find.widgetWithText(MenuItemButton, tool.label), findsOneWidget);
    }
    expect(find.widgetWithText(MenuItemButton, 'Set trip dates and travellers'), findsOneWidget);
    expect(find.widgetWithText(SubmenuButton, 'Open a saved plan'), findsOneWidget);

    await tester.tap(find.widgetWithText(MenuItemButton, 'Travel info'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Visa and weather for Rome');
    expect(sent, isEmpty);
  });
}
