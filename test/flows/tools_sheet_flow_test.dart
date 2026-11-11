import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../account/fakes.dart';
import '../features/chat/fakes.dart';
import '../itinerary/fakes.dart';

void main() {
  testWidgets('390 px: "+" → Hotels fills the composer, nothing is sent; Set trip dates updates the chip', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final transport = FakeChatTransport();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...signedIn(),
          ...chatOverrides(transport),
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
    // The trip chip starts from the latest plan.
    expect(find.bySemanticsLabel('Rome · 10 – 14 Apr'), findsOneWidget);

    await tester.tap(find.byTooltip('Tools, trip and plans'));
    await tester.pumpAndSettle();
    expect(find.text('What can I help with?'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Hotels, Ranked for you'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Find hotels in Rome for 10 – 14 Apr');
    expect(transport.posts, isEmpty);

    await tester.tap(find.byTooltip('Tools, trip and plans'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set trip dates and travellers'));
    await tester.pumpAndSettle();
    expect(find.text('Your trip'), findsOneWidget);
    await tester.tap(find.byTooltip('More adults'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Rome · 10 – 14 Apr · 3 adults'), findsOneWidget);
    expect(transport.posts, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
