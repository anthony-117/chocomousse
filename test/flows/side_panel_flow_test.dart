import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/shell/recents_list.dart';
import 'package:chocomousse/features/shell/sidebar.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:chocomousse/features/side_panel/presentation/side_panel.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../account/fakes.dart';
import '../features/chat/fakes.dart';
import '../helpers.dart';
import '../itinerary/fakes.dart';

FakeChatApi _api() => FakeChatApi(
  chats: [
    chatJson(),
    chatJson(
      id: 'c2',
      title: 'Lisbon weekend',
      messages: [
        {'id': '0001', 'role': 'traveller', 'text': 'Any jazz bars in Lisbon?', 'at': '2026-11-10T19:00:00Z'},
        {
          'id': '0002',
          'role': 'assistant',
          'text': 'Two good ones.',
          'steps': <Object>[],
          'cards': [eventCardJson()],
          'at': '2026-11-10T19:02:11Z',
        },
      ],
    ),
  ],
);

Future<void> _pumpApp(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...signedIn(),
        ...chatApiOverrides(_api()),
        planRepositoryProvider.overrideWithValue(FakePlanRepository()),
        pingProvider.overrideWith(
          (ref) async =>
              PingInfo(name: 'pamplemousse', version: '1.0.0', environment: 'Test', utcNow: DateTime.utc(2026)),
        ),
      ],
      child: const TravelGenieApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _tab(PanelPane pane) =>
    find.descendant(of: find.byType(PanelIconBar), matching: find.bySemanticsLabel(pane.label));

PanelPane _active(WidgetTester tester) => tester.widget<PanelIconBar>(find.byType(PanelIconBar)).active;

double _sidebarWidth(WidgetTester tester) => tester.getSize(find.byType(Sidebar)).width;

Future<void> _openChat(WidgetTester tester, String title) async {
  await tester.tap(find.descendant(of: find.byType(RecentsList), matching: find.text(title)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('1440 px: every pane opens from the icon bar beside the chat; each chat keeps its pane', (tester) async {
    await _pumpApp(tester, const Size(1440, 1000));
    await _openChat(tester, 'Rome in April');
    expect(find.byType(SidePanel), findsNothing);

    await tester.tap(find.text('Open plan').first);
    await tester.pumpAndSettle();
    expect(find.byType(SidePanel), findsOneWidget);
    expect(_active(tester), PanelPane.plan);

    for (final pane in PanelPane.values) {
      await tester.tap(_tab(pane));
      await tester.pumpAndSettle();
      expect(_active(tester), pane);
      expect(find.text('Here is a 5-day plan.'), findsOneWidget, reason: 'the chat stays visible beside ${pane.label}');
    }
    await tester.tap(_tab(PanelPane.map));
    await tester.pumpAndSettle();
    expect(_sidebarWidth(tester), Sidebar.width, reason: 'at 1440 px the sidebar stays open');

    await _openChat(tester, 'Lisbon weekend');
    expect(find.byType(SidePanel), findsNothing, reason: "the other chat's panel is its own");

    await _openChat(tester, 'Rome in April');
    expect(find.byType(SidePanel), findsOneWidget);
    expect(_active(tester), PanelPane.map);
    expect(tester.takeException(), isNull);
  });

  testWidgets('1100 px: with the panel open the sidebar is a rail, and opens again when the panel closes', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(1100, 1000));
    await _openChat(tester, 'Rome in April');
    expect(_sidebarWidth(tester), Sidebar.width);

    await tester.tap(find.text('Open plan').first);
    await tester.pumpAndSettle();
    expect(find.byType(SidePanel), findsOneWidget);
    expect(_sidebarWidth(tester), Sidebar.railWidth);
    expect(find.byTooltip('Close the panel to open the sidebar'), findsOneWidget);
    expect(find.text('Here is a 5-day plan.'), findsOneWidget);

    await tester.tap(find.byTooltip('Close panel'));
    await tester.pumpAndSettle();
    expect(find.byType(SidePanel), findsNothing);
    expect(_sidebarWidth(tester), Sidebar.width);
    expect(tester.takeException(), isNull);
  });

  testWidgets('910 px: opening the panel never squeezes the chat while the sidebar folds', (tester) async {
    await _pumpApp(tester, const Size(910, 1000));
    await _openChat(tester, 'Rome in April');

    await tester.tap(find.text('Open plan').first);
    // Frame by frame: an overflow in any frame of the fold is an error.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();

    expect(find.byType(SidePanel), findsOneWidget);
    expect(_sidebarWidth(tester), Sidebar.railWidth);
    expect(tester.takeException(), isNull);
  });

  testWidgets('390 px: the panel is a sheet with the same icon bar', (tester) async {
    await _pumpApp(tester, const Size(390, 1000));
    await openShellPlace(tester, 'Rome in April');
    expect(find.byType(Sidebar), findsNothing);

    await tester.tap(find.text('Open plan').first);
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(find.descendant(of: sheet, matching: find.byType(PanelIconBar)), findsOneWidget);
    for (final pane in PanelPane.values) {
      expect(_tab(pane), findsOneWidget);
    }
    await tester.tap(_tab(PanelPane.saved));
    await tester.pumpAndSettle();
    expect(_active(tester), PanelPane.saved);

    await tester.tap(find.byTooltip('Close panel'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
