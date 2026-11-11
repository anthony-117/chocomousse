import 'package:chocomousse/features/account/application/session.dart';
import 'package:chocomousse/features/chat/application/chat_trip.dart';
import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/chat/presentation/composer.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../../account/fakes.dart';
import '../../../helpers.dart';
import '../fakes.dart';

List<Override> composerOverrides() => [
  ...chatOverrides(FakeChatTransport()),
  plansProvider.overrideWith((ref) => const PlanList(items: [], count: 0, max: 50)),
  profileProvider.overrideWith((ref) => defaultProfile()),
];

void main() {
  test('the chips read the trip and the two strongest interests', () {
    expect(tripChipLabel(ChatTrip.empty), 'Add trip');
    expect(
      tripChipLabel(
        ChatTrip(destinationName: 'Rome', from: DateTime(2027, 4, 10), to: DateTime(2027, 4, 14), adults: 2),
      ),
      'Rome · 10 – 14 Apr · 2 adults',
    );
    expect(preferencesChipLabel(const ChatTripState()), 'Add preferences');
    expect(
      preferencesChipLabel(
        const ChatTripState(preferences: {'culture': 90, 'food': 50, 'nature': 10, 'nightlife': 50, 'budget': 90}),
      ),
      'Culture · Food · Balanced',
    );
    expect(
      preferencesChipLabel(const ChatTripState(preferences: {'nightlife': 90, 'nature': 90}, pace: Pace.packed)),
      'Nature · Nightlife · Packed',
    );
  });

  for (final size in [phone, desktop]) {
    final width = size.width.toInt();

    forBothModes('sends the trimmed text once, then clears ($width)', (tester, mode) async {
      final sent = <String>[];
      await pumpApp(
        tester,
        Composer(onSend: sent.add),
        size: size,
        mode: mode,
        overrides: composerOverrides(),
      );
      await tester.pumpAndSettle();
      final send = find.byTooltip('Send');
      expect(
        tester.widget<IconButton>(find.ancestor(of: send, matching: find.byType(IconButton)).first).onPressed,
        isNull,
      );

      await tester.enterText(find.byType(TextField), '  Plan 5 days in Rome  ');
      await tester.pump();
      await tester.tap(send);
      await tester.pump();
      expect(sent, ['Plan 5 days in Rome']);
      expect(find.text('Plan 5 days in Rome'), findsNothing);
      expect(find.text(kAiNotice), findsOneWidget);
    });
  }

  testWidgets('keeps at most 1,000 characters', (tester) async {
    await pumpApp(tester, Composer(onSend: (_) {}), overrides: composerOverrides());
    await tester.enterText(find.byType(TextField), 'a' * 1200);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, hasLength(kMaxMessageLength));
  });

  testWidgets('nothing is sent while an answer runs', (tester) async {
    final sent = <String>[];
    await pumpApp(tester, Composer(onSend: sent.add, sending: true), overrides: composerOverrides());
    await tester.enterText(find.byType(TextField), 'Hi');
    await tester.tap(find.byTooltip('Send'));
    expect(sent, isEmpty);
  });

  testWidgets('Enter sends; Shift+Enter does not', (tester) async {
    final sent = <String>[];
    await pumpApp(tester, Composer(onSend: sent.add, enterSends: true), overrides: composerOverrides());
    await tester.enterText(find.byType(TextField), 'Hotels in Rome');
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(sent, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(sent, ['Hotels in Rome']);
  });

  testWidgets('the trip chip edits the trip; the preferences chip the sliders and pace', (tester) async {
    await pumpApp(
      tester,
      Composer(onSend: (_) {}),
      size: desktop,
      overrides: composerOverrides(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Add trip'));
    await tester.pumpAndSettle();
    expect(find.text('Your trip'), findsOneWidget);
    await tester.tap(find.byTooltip('More adults'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('3 adults'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp(r'·.*(Relaxed|Balanced|Packed)$')));
    await tester.pumpAndSettle();
    expect(find.text('My preferences'), findsOneWidget);
    await tester.tap(find.text('Packed'));
    await tester.pump();
    await tester.ensureVisible(find.text('Done'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp(r'· Packed$')), findsOneWidget);
  });
}
