import 'dart:async';

import 'package:chocomousse/core/widgets/skeleton.dart';
import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/saved/data/saved_repository.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:chocomousse/features/side_panel/presentation/saved_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';
import '../chat/fakes.dart';
import '../saved/fakes.dart';

Future<FakeSavedRepository> _withItems() async {
  final saved = FakeSavedRepository();
  for (final json in [
    hotelCardJson(),
    placeCardJson(),
    eventCardJson(),
    hotelCardJson(id: 'bk:2'),
    placeCardJson(id: 'otm:N9'),
  ]) {
    await saved.save(AssistantCard.fromJson(json)!, destinationId: '3169070');
  }
  saved.calls.clear();
  return saved;
}

void main() {
  for (final size in [phone, desktop]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${size.width.toInt()} px (${mode.name}): Hotels, Places and Events, newest first', (tester) async {
        final saved = await _withItems();
        await pumpApp(
          tester,
          const SavedPane(chatKey: 'c1'),
          size: size,
          mode: mode,
          overrides: bookmarkOverrides(saved),
        );
        await tester.pumpAndSettle();

        final labels = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .where((t) => t == 'HOTELS' || t == 'PLACES' || t == 'EVENTS')
            .toList();
        expect(labels, ['HOTELS', 'PLACES', 'EVENTS']);
        expect(find.bySemanticsLabel('Hotel Artemide, Rome'), findsNWidgets(2));
        expect(find.bySemanticsLabel('Colosseum, Rome'), findsNWidgets(2));
        expect(find.bySemanticsLabel('Jazz at the Baths, Rome'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('a row opens its item in Details', (tester) async {
    final saved = await _withItems();
    await pumpApp(
      tester,
      const SavedPane(chatKey: 'c1'),
      size: desktop,
      overrides: bookmarkOverrides(saved),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Jazz at the Baths, Rome'));
    await tester.pump();
    final panel = ProviderScope.containerOf(tester.element(find.byType(SavedPane))).read(sidePanelProvider('c1'));
    expect(panel.pane, PanelPane.details);
    expect(panel.selected, isA<EventCard>());
  });

  testWidgets('loading shows skeleton rows', (tester) async {
    final saved = FakeSavedRepository()..gate = Completer<void>();
    await pumpApp(tester, const SavedPane(chatKey: 'c1'), overrides: bookmarkOverrides(saved));
    await tester.pump();
    expect(find.byType(SkeletonBox), findsWidgets);
    saved.gate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('empty says how to save', (tester) async {
    await pumpApp(tester, const SavedPane(chatKey: 'c1'), overrides: bookmarkOverrides(FakeSavedRepository()));
    await tester.pumpAndSettle();
    expect(find.text(kSavedEmpty), findsOneWidget);
  });

  testWidgets('an error shows Try again, which loads again', (tester) async {
    final saved = FakeSavedRepository()..failWith = TooManySaved(1);
    await pumpApp(tester, const SavedPane(chatKey: 'c1'), overrides: bookmarkOverrides(saved));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text(kSavedEmpty), findsOneWidget);
  });
}
