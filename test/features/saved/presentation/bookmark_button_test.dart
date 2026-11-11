import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/saved/presentation/bookmark_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers.dart';
import '../../chat/fakes.dart';
import '../fakes.dart';

void main() {
  final hotel = AssistantCard.fromJson(hotelCardJson())!;

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('outlined, then filled once saved, then outlined again (${mode.name})', (tester) async {
      final saved = FakeSavedRepository();
      await pumpApp(
        tester,
        Center(child: BookmarkButton(card: hotel)),
        mode: mode,
        overrides: bookmarkOverrides(saved),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Save Hotel Artemide'), findsOneWidget);

      await tester.tap(find.byTooltip('Save Hotel Artemide'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remove Hotel Artemide from Saved'), findsOneWidget);
      expect(saved.items.single.destinationId, '3169070');

      await tester.tap(find.byTooltip('Remove Hotel Artemide from Saved'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Save Hotel Artemide'), findsOneWidget);
      expect(saved.items, isEmpty);
    });
  }

  testWidgets('labelled in Details: Save, then Saved', (tester) async {
    await pumpApp(
      tester,
      Center(child: BookmarkButton(card: hotel, labelled: true)),
      size: desktop,
      overrides: bookmarkOverrides(FakeSavedRepository()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('a failure changes it back and shows a snack bar', (tester) async {
    final saved = FakeSavedRepository();
    await pumpApp(
      tester,
      Center(child: BookmarkButton(card: hotel)),
      overrides: bookmarkOverrides(saved),
    );
    await tester.pumpAndSettle();
    saved.failWith = savedProblem(500, {});
    await tester.tap(find.byTooltip('Save Hotel Artemide'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't save. Try again."), findsOneWidget);
    expect(find.byTooltip('Save Hotel Artemide'), findsOneWidget);
  });

  testWidgets('nothing for a flight or a car', (tester) async {
    await pumpApp(
      tester,
      Column(
        children: [
          BookmarkButton(card: AssistantCard.fromJson(flightCardJson())!),
          BookmarkButton(card: AssistantCard.fromJson(carCardJson())!),
        ],
      ),
      overrides: bookmarkOverrides(FakeSavedRepository()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
