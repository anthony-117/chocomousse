import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/side_panel/presentation/side_panel.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../account/fakes.dart';
import '../features/chat/fakes.dart';
import '../helpers.dart';
import '../itinerary/fakes.dart';

/// Spec 008 T093: on phones every control is labelled and at least 48 × 48, and cards read as one sentence.
void main() {
  final api = FakeChatApi(
    chats: [
      chatJson(
        messages: [
          {'id': '0001', 'role': 'traveller', 'text': 'Everything for Rome', 'at': '2026-11-10T19:00:00Z'},
          {
            'id': '0002',
            'role': 'assistant',
            'text': 'Here it all is.',
            'steps': <Object>[],
            'cards': [
              planCardJson(),
              flightCardJson(),
              hotelCardJson(),
              carCardJson(),
              placeCardJson(),
              eventCardJson(),
            ],
            'at': '2026-11-10T19:02:11Z',
          },
        ],
      ),
    ],
  );

  Future<void> pumpPhone(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...signedIn(),
          ...chatApiOverrides(api),
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

  testWidgets('390 px: the home and the tools sheet', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpPhone(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    await tester.tap(find.byTooltip('Tools, trip and plans'));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('390 px: a chat with every card kind, and its panel sheet', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpPhone(tester);
    await openShellPlace(tester, 'Rome in April');
    expect(find.bySemanticsLabel(r'Hotel Artemide, 88% match, $203 a night'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Colosseum, Sight')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Jazz at the Baths, ')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^[A-Z]{3} → [A-Z]{3}, \d+% match, ')), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    await tester.tap(find.text('Open plan').first);
    await tester.pumpAndSettle();
    expect(find.byType(PanelIconBar), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
