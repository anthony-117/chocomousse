import 'package:chocomousse/features/account/application/session.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../account/fakes.dart';
import '../../helpers.dart';
import '../../itinerary/fakes.dart';
import '../chat/fakes.dart';

/// A panel widget of chat `c1`, with the chat API, the plans and the profile faked.
class PanelFixture {
  PanelFixture({List<Map<String, Object?>>? chats, FakePlanRepository? plans})
    : api = FakeChatApi(chats: chats ?? [chatJson()]),
      plans = plans ?? FakePlanRepository();

  final FakeChatApi api;
  final FakePlanRepository plans;
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, Widget child, {Size size = desktop, ThemeMode mode = ThemeMode.light}) async {
    await pumpApp(
      tester,
      child,
      size: size,
      mode: mode,
      overrides: [
        ...chatApiOverrides(api),
        planRepositoryProvider.overrideWithValue(plans),
        plansProvider.overrideWith((ref) => const PlanList(items: [], count: 0, max: 50)),
        profileProvider.overrideWith((ref) => defaultProfile()),
      ],
    );
    container = ProviderScope.containerOf(tester.element(find.byWidget(child)));
    await tester.pumpAndSettle();
  }
}
