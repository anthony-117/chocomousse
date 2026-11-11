import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/shell/recents_list.dart';
import 'package:chocomousse/features/side_panel/presentation/side_panel.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../account/fakes.dart';
import '../features/chat/fakes.dart';
import '../itinerary/fakes.dart';

/// An answer of a chat that already exists: its steps, then the final.
String _answer(Map<String, Object?> last, {List<Map<String, Object?>> steps = const []}) =>
    [for (final step in steps) sse('step', step), sse('final', last)].join();

void main() {
  testWidgets('swap a day item through the chat, then "+" a hotel into the plan', (tester) async {
    tester.view
      ..physicalSize = const Size(1440, 1200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final plans = FakePlanRepository();
    final api = FakeChatApi(chats: [chatJson()]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...signedIn(),
          ...chatApiOverrides(api),
          planRepositoryProvider.overrideWithValue(plans),
          pingProvider.overrideWith(
            (ref) async =>
                PingInfo(name: 'pamplemousse', version: '1.0.0', environment: 'Test', utcNow: DateTime.utc(2026)),
          ),
        ],
        child: const TravelGenieApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(RecentsList), matching: find.text('Rome in April')));
    await tester.pumpAndSettle();

    // Open the plan, go to day 2, and ask for alternatives to the Colosseum.
    await tester.tap(find.text('Open plan'));
    await tester.pumpAndSettle();
    final panel = find.byType(SidePanel);
    await tester.tap(find.descendant(of: panel, matching: find.text('Day 2')));
    await tester.pumpAndSettle();
    api.transport.reply(
      _answer(
        finalJson(
          messageId: '0004',
          text: 'Two places near the Colosseum.',
          cards: [
            alternativeCardJson(),
            alternativeCardJson(id: 'otm:pantheon', name: 'Pantheon'),
          ],
          suggestions: const ['Use Villa Borghese'],
        ),
        steps: [
          stepJson(
            tool: 'suggest_day_alternatives',
            summary: 'Found 2 alternatives for day 2',
            total: 2,
            cards: [alternativeCardJson()],
          ),
        ],
      ),
    );
    await tester.tap(find.byTooltip('Alternatives to Colosseum'));
    await tester.pumpAndSettle();
    final ask = api.transport.posts.last;
    expect(ask.body['text'], 'Show me alternatives to Colosseum on day 2');
    expect(ask.body['about'], {'planId': 'p1', 'day': 2, 'itemId': 'wd:Q10285'});
    expect(find.text('Two places near the Colosseum.'), findsOneWidget);
    expect(find.text('PLACES'), findsOneWidget);

    // "Use Villa Borghese": the assistant changes the day, and the Plan pane reloads with it.
    await plans.addOrReplaceItem('p1', 2, kind: RefKind.place, itemId: 'otm:N123', replaces: 'wd:Q10285');
    api.transport.reply(
      _answer(
        finalJson(
          messageId: '0006',
          text: 'Villa Borghese is in, in place of the Colosseum. Here is another hotel too.',
          cards: [hotelCardJson(id: 'bk:2')],
          suggestions: const [],
          planChanged: 'p1',
        ),
      ),
    );
    await tester.tap(find.text('Use Villa Borghese'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.descendant(of: panel, matching: find.text('Villa Borghese')), findsOneWidget);
    expect(find.descendant(of: panel, matching: find.text('Colosseum')), findsNothing);
    expect(find.text('Plan updated'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // "+" on the new hotel swaps it in, and the chat notes it.
    await tester.tap(find.byTooltip('Swap into plan'));
    await tester.pumpAndSettle();
    expect(plans.asked, contains('swap p1 hotel bk:2'));
    expect(find.text('Swapped in Hotel Artemide'), findsOneWidget);
    await tester.tap(find.descendant(of: panel, matching: find.text('Hotel')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: panel, matching: find.text('Hotel Santa Maria')), findsOneWidget);
    expect(api.transport.posts, hasLength(2), reason: 'the swap went to the plan, not the chat');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
