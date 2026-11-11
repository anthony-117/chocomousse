import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

/// The side panel's panes, in the icon bar's order.
enum PanelPane { trip, plan, details, map, saved }

@immutable
class SidePanelState {
  const SidePanelState({this.open = false, this.pane = PanelPane.trip, this.selected, this.planId});

  final bool open;
  final PanelPane pane;

  /// The card shown in Details.
  final AssistantCard? selected;

  /// The plan shown in the Plan pane.
  final String? planId;

  SidePanelState copyWith({bool? open, PanelPane? pane, AssistantCard? selected, String? planId}) => SidePanelState(
    open: open ?? this.open,
    pane: pane ?? this.pane,
    selected: selected ?? this.selected,
    planId: planId ?? this.planId,
  );
}

/// The side panel of one chat, or of the home (key `home`). Kept for the app session (data-model "Side panel").
class SidePanelController extends Notifier<SidePanelState> {
  SidePanelController(this.chatKey);

  final String chatKey;

  @override
  SidePanelState build() => const SidePanelState();

  /// A plan card opens the Plan pane on that plan; any other card opens Details.
  void openCard(AssistantCard card) => state = switch (card) {
    PlanCard(:final plan) => state.copyWith(open: true, pane: PanelPane.plan, planId: plan.id),
    _ => state.copyWith(open: true, pane: PanelPane.details, selected: card),
  };

  void openPane(PanelPane pane) => state = state.copyWith(open: true, pane: pane);

  void openPlan(String id) => state = state.copyWith(open: true, pane: PanelPane.plan, planId: id);

  void close() => state = state.copyWith(open: false);

  /// Takes another panel's state: a chat started from the home keeps the home's panel.
  // A method, as the other changes are, not a setter.
  // ignore: use_setters_to_change_properties
  void adopt(SidePanelState other) => state = other;
}

/// The key of the home's panel.
const homePanelKey = 'home';

final NotifierProviderFamily<SidePanelController, SidePanelState, String> sidePanelProvider =
    NotifierProvider.family<SidePanelController, SidePanelState, String>(SidePanelController.new);
