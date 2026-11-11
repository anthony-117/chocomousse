import 'package:chocomousse/core/widgets/skeleton.dart';
import 'package:chocomousse/features/account/application/session.dart';
import 'package:chocomousse/features/chat/application/chat_trip.dart';
import 'package:chocomousse/features/chat/presentation/chat_screen.dart';
import 'package:chocomousse/features/chat/presentation/widgets/chat_bits.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../account/fakes.dart';
import '../../../helpers.dart';
import '../fakes.dart';

Future<ProviderContainer> _open(WidgetTester tester, FakeChatApi api, {Size size = desktop, bool settle = true}) async {
  await pumpApp(
    tester,
    const ChatScreen(chatId: 'c1'),
    size: size,
    overrides: [
      ...chatApiOverrides(api),
      plansProvider.overrideWith((ref) => const PlanList(items: [], count: 0, max: 50)),
      profileProvider.overrideWith((ref) => defaultProfile()),
    ],
  );
  if (settle) await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(ChatScreen)));
}

void main() {
  for (final size in [phone, desktop]) {
    testWidgets('a stored chat opens with its messages and cards (${size.width.toInt()})', (tester) async {
      await _open(tester, FakeChatApi(chats: [chatJson()]), size: size);
      expect(find.text('Plan Rome'), findsOneWidget);
      expect(find.text('Here is a 5-day plan.'), findsOneWidget);
      expect(find.text('PLAN'), findsOneWidget);
    });
  }

  testWidgets('while it opens it shows three message blocks', (tester) async {
    await _open(tester, FakeChatApi(chats: [chatJson()]), settle: false);
    expect(find.byType(SkeletonBox), findsNWidgets(3));
    await tester.pumpAndSettle();
    expect(find.byType(SkeletonBox), findsNothing);
  });

  testWidgets('a chat that expired says so and offers a new trip chat', (tester) async {
    await _open(tester, FakeChatApi());
    expect(find.text('This chat has expired'), findsOneWidget);
    expect(find.text('New trip chat'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('a chat still answering elsewhere shows it and holds the composer', (tester) async {
    await _open(tester, FakeChatApi(chats: [chatJson(busy: true)]), settle: false);
    await tester.pump();
    await tester.pump();
    expect(find.text('Still answering on another device…'), findsOneWidget);
    expect(find.byType(WorkingIndicator), findsOneWidget);
    // The chat is checked again every 5 s; stop the checks by leaving.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
  });

  testWidgets("the chips take the chat's trip, preferences and pace, and a message continues the chat", (tester) async {
    final api = FakeChatApi(
      chats: [
        chatJson(
          trip: {'destinationId': '3169070', 'destinationName': 'Rome', 'from': '2027-04-10', 'to': '2027-04-14'},
          preferences: {'culture': 90, 'food': 70, 'nature': 10, 'nightlife': 10, 'budget': 50, 'rating': 50},
          pace: 'relaxed',
        ),
      ],
    );
    final container = await _open(tester, api);
    final chips = container.read(chatTripProvider);
    expect(chips.trip.destinationId, '3169070');
    expect((chips.preferences['culture'], chips.preferencesChanged), (90, true));
    expect((chips.pace, chips.paceChanged), (Pace.relaxed, true));

    await tester.enterText(find.byType(TextField), 'Add a car');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    final post = api.transport.posts.single;
    expect(post.path, '/assistant/chats/c1/messages');
    expect(post.body['pace'], 'relaxed');
    expect((post.body['trip']! as Map)['destinationId'], '3169070');
    expect(find.text('Here is a 5-day plan.'), findsNWidgets(2), reason: 'the answer appends');
  });
}
