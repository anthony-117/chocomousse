import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/hotels/data/hotel_repository.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/saved/data/saved_models.dart';
import 'package:chocomousse/features/shell/recents_list.dart';
import 'package:chocomousse/features/side_panel/presentation/details_pane.dart';
import 'package:chocomousse/features/side_panel/presentation/saved_pane.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../account/fakes.dart';
import '../destination/fakes.dart';
import '../features/chat/fakes.dart';
import '../features/saved/fakes.dart';
import '../helpers.dart';
import '../hotels/fakes.dart';
import '../itinerary/fakes.dart';

Widget _app(FakeChatApi api, FakeSavedRepository saved) => ProviderScope(
  overrides: [
    ...signedIn(),
    ...chatApiOverrides(api, saved: saved),
    planRepositoryProvider.overrideWithValue(FakePlanRepository()),
    hotelRepositoryProvider.overrideWithValue(FakeHotelRepository()),
    destinationRepositoryProvider.overrideWithValue(FakeDestinationRepository()),
    pingProvider.overrideWith(
      (ref) async => PingInfo(name: 'pamplemousse', version: '1.0.0', environment: 'Test', utcNow: DateTime.utc(2026)),
    ),
  ],
  child: const TravelGenieApp(),
);

void main() {
  testWidgets('bookmark a hotel and a place → Saved groups them → open the hotel → remove it → a new app keeps the '
      'place', (tester) async {
    tester.view
      ..physicalSize = const Size(1440, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final saved = FakeSavedRepository();
    final api = FakeChatApi(
      chats: [
        chatJson(
          messages: [
            {'id': '0001', 'role': 'traveller', 'text': 'Hotels and sights in Rome', 'at': '2026-11-10T19:00:00Z'},
            {
              'id': '0002',
              'role': 'assistant',
              'text': 'Here are a few.',
              'steps': <Object>[],
              'cards': [
                {...hotelCardJson(), 'destinationId': '3169070', 'destinationName': 'Rome'},
                {...placeCardJson(), 'destinationId': '3169070', 'destinationName': 'Rome'},
              ],
              'at': '2026-11-10T19:02:11Z',
            },
          ],
        ),
      ],
    );

    await tester.pumpWidget(_app(api, saved));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(RecentsList), matching: find.text('Rome in April')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save Hotel Artemide'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save Colosseum'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove Hotel Artemide from Saved'), findsOneWidget);
    expect(find.byTooltip('Remove Colosseum from Saved'), findsOneWidget);
    expect(saved.items.map((i) => (i.kind, i.id, i.destinationId)), [
      (SavedKind.hotel, 'bk:1', '3169070'),
      (SavedKind.place, 'wd:Q10285', '3169070'),
    ]);

    await openShellPlace(tester, 'Saved');
    final pane = find.byType(SavedPane);
    expect(pane, findsOneWidget);
    expect(find.descendant(of: pane, matching: find.text('HOTELS')), findsOneWidget);
    expect(find.descendant(of: pane, matching: find.text('PLACES')), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Hotel Artemide, Rome'));
    await tester.pumpAndSettle();
    final details = find.byType(DetailsPane);
    expect(details, findsOneWidget);
    final savedButton = find.descendant(of: details, matching: find.text('Saved'));
    await tester.scrollUntilVisible(
      savedButton,
      300,
      scrollable: find.descendant(of: details, matching: find.byType(Scrollable)).first,
    );
    await tester.tap(savedButton);
    await tester.pumpAndSettle();
    expect(find.descendant(of: details, matching: find.text('Save')), findsOneWidget);
    expect(saved.items.single.id, 'wd:Q10285');

    // A new app on the same account.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(api, saved));
    await tester.pumpAndSettle();
    await openShellPlace(tester, 'Saved');
    expect(find.bySemanticsLabel('Colosseum, Rome'), findsOneWidget);
    expect(find.bySemanticsLabel('Hotel Artemide, Rome'), findsNothing);
    expect(find.descendant(of: find.byType(SavedPane), matching: find.text('HOTELS')), findsNothing);
  });
}
