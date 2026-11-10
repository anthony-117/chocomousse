import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat/fakes.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  SidePanelController panel([String key = 'c1']) => container.read(sidePanelProvider(key).notifier);
  SidePanelState state([String key = 'c1']) => container.read(sidePanelProvider(key));

  test('starts closed on the Trip pane', () {
    expect(state().open, isFalse);
    expect(state().pane, PanelPane.trip);
  });

  test('a plan card opens the Plan pane on that plan', () {
    panel().openCard(AssistantCard.fromJson(planCardJson(id: 'p7').cast())!);
    expect(state().open, isTrue);
    expect(state().pane, PanelPane.plan);
    expect(state().planId, 'p7');
  });

  test('another card opens Details with that card', () {
    final hotel = AssistantCard.fromJson(hotelCardJson().cast())!;
    panel().openCard(hotel);
    expect(state().pane, PanelPane.details);
    expect(state().selected, same(hotel));
  });

  test('openPane, openPlan and close', () {
    panel().openPane(PanelPane.map);
    expect((state().open, state().pane), (true, PanelPane.map));
    panel().openPlan('p2');
    expect((state().pane, state().planId), (PanelPane.plan, 'p2'));
    panel().close();
    expect(state().open, isFalse);
    expect(state().planId, 'p2', reason: 'the panel reopens where it was');
  });

  test('each chat has its own panel', () {
    panel().openPane(PanelPane.saved);
    expect(state(homePanelKey).open, isFalse);
  });
}
