import 'package:chocomousse/core/widgets/cards/pin_preview.dart';
import 'package:chocomousse/features/chat/application/chat_controller.dart';
import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:chocomousse/features/side_panel/presentation/map_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';
import '../chat/fakes.dart';

Map<String, Object?> _chat(List<Map<String, Object?>> cards) => {
  'id': 'c1',
  'title': 'Rome',
  'createdAt': '2026-11-09T18:40:00Z',
  'lastMessageAt': '2026-11-10T19:02:11Z',
  'expiresAt': '2027-02-08T19:02:11Z',
  'busy': false,
  'messages': [
    {'id': '0001', 'role': 'traveller', 'text': 'Rome', 'at': '2026-11-10T19:00:00Z'},
    {
      'id': '0002',
      'role': 'assistant',
      'text': 'Here.',
      'steps': [
        stepJson(tool: 'search_hotels', cards: [hotelCardJson()]),
      ],
      'cards': cards,
      'at': '2026-11-10T19:02:11Z',
    },
  ],
};

Future<ProviderContainer> _pane(
  WidgetTester tester,
  List<Map<String, Object?>> cards, {
  Size size = desktop,
  ThemeMode mode = ThemeMode.light,
}) async {
  await pumpApp(
    tester,
    const SizedBox(width: 520, child: MapPane(chatKey: 'c1')),
    size: size,
    mode: mode,
    overrides: chatOverrides(FakeChatTransport(), answers: [(200, _chat(cards))]),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(MapPane)));
}

void main() {
  for (final size in [phone, desktop]) {
    forBothModes('shows a pin for each hotel, place and event, once (${size.width.toInt()})', (tester, mode) async {
      await _pane(
        tester,
        [hotelCardJson(), placeCardJson(), eventCardJson(withLocation: false), flightCardJson()],
        size: size,
        mode: mode,
      );
      final pins = tester.widget<PinPreview>(find.byType(PinPreview)).pins;
      expect(pins.map((p) => p.kind), [
        PinKind.hotel,
        PinKind.place,
        PinKind.event,
      ], reason: 'no flight, the hotel once');
      expect(pins.last.approximate, isTrue);
      expect(find.text('Some places show the city centre'), findsOneWidget);
    });
  }

  testWidgets('a tap on a row opens the card in Details', (tester) async {
    final container = await _pane(tester, [placeCardJson()]);
    await tester.tap(find.text('Colosseum'));
    await tester.pump();
    final panel = container.read(sidePanelProvider('c1'));
    expect(panel.pane, PanelPane.details);
    expect(panel.selected?.id, 'wd:Q10285');
  });

  testWidgets('without pins it says when they show', (tester) async {
    await pumpApp(
      tester,
      const MapPane(chatKey: 'c1'),
      overrides: chatOverrides(
        FakeChatTransport(),
        answers: [
          (200, {..._chat(const []), 'messages': <Object>[]}),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pins show here when the assistant finds hotels, places or events.'), findsOneWidget);
  });

  test('a chat card shows once, where it first came, in its latest version', () {
    ChatMessage answer(String id, List<Map<String, Object?>> cards) => ChatMessage(
      id: id,
      role: ChatRole.assistant,
      text: '',
      at: DateTime.utc(2026, 11, 11),
      cards: [for (final c in cards) AssistantCard.fromJson(c)!],
    );
    final chat = ChatState(
      messages: [
        answer('0002', [planCardJson(name: 'Rome, first'), hotelCardJson()]),
        answer('0004', [planCardJson(name: 'Rome, changed')]),
      ],
    );

    final cards = chatCards(chat);

    expect(cards.map((c) => c.kind), ['plan', 'hotel']);
    expect((cards.first as PlanCard).plan.name, 'Rome, changed');
  });
}
