import 'dart:async';

import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/features/chat/application/chat_controller.dart';
import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The chat a panel belongs to; null for the home's, whose messages start a new chat.
String? chatOfPanel(String chatKey) => chatKey == homePanelKey ? null : chatKey;

/// Sends [text] to the chat of [chatKey]'s panel (spec 008 US3). From the home it starts a new chat, which takes the
/// home's panel along, and opens it. On phones the panel is a sheet; it closes so the answer shows.
void sendFromPanel(BuildContext context, WidgetRef ref, String chatKey, String text, {MessageAbout? about}) {
  final chat = ref.read(chatProvider(chatOfPanel(chatKey)).notifier);
  if (chatKey == homePanelKey) {
    final router = GoRouter.of(context);
    final container = ProviderScope.containerOf(context);
    chat.onChatCreated = (id) {
      container.read(sidePanelProvider(id).notifier).adopt(container.read(sidePanelProvider(homePanelKey)));
      unawaited(router.replace<void>('/chat/$id'));
    };
  }
  unawaited(chat.send(text, about: about));
  if (MediaQuery.sizeOf(context).width < kWideLayoutBreakpoint) Navigator.of(context).maybePop();
}

/// The plan a card's "+" goes to: the one open in the panel, else the chat's latest plan card.
String? planForCards(WidgetRef ref, String chatKey) {
  final open = ref.read(sidePanelProvider(chatKey)).planId;
  if (open != null) return open;
  // Only a chat already open is read, so a label never starts loading one.
  final provider = chatProvider(chatOfPanel(chatKey));
  if (!ref.exists(provider)) return null;
  final chat = ref.read(provider);
  for (final message in chat.messages.reversed) {
    for (final card in message.cards.reversed) {
      if (card is PlanCard) return card.plan.id;
    }
  }
  return null;
}

/// "Add to plan" or "Swap into plan", for a hotel or car card.
String planActionLabel(WidgetRef ref, String chatKey, AssistantCard card) {
  final planId = planForCards(ref, chatKey);
  if (planId == null) return 'Add to plan';
  final plan = ref.exists(planProvider(planId)) ? ref.read(planProvider(planId)).value : null;
  return switch (card) {
    CarCard() when plan != null && plan.car == null => 'Add to plan',
    _ => 'Swap into plan',
  };
}

/// "+" on a hotel or car card (spec 008 US3): swaps it into the plan and opens the Plan pane, with a note in the
/// chat. An offer the plan no longer has asks the assistant instead; without a plan, the assistant builds one.
Future<void> addCardToPlan(BuildContext context, WidgetRef ref, String chatKey, AssistantCard card) async {
  final (kind, name) = switch (card) {
    HotelCard(:final hotel) => (OfferKind.hotel, hotel.name),
    CarCard(:final car) => (OfferKind.car, car.model),
    _ => throw ArgumentError('Only hotels and cars go into a plan'),
  };
  final planId = planForCards(ref, chatKey);
  if (planId == null) {
    sendFromPanel(context, ref, chatKey, 'Build a plan with $name');
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  final panel = ref.read(sidePanelProvider(chatKey).notifier);
  final chat = ref.read(chatProvider(chatOfPanel(chatKey)).notifier);
  try {
    await ref.read(planActionsProvider).swap(planId, kind, card.id);
    panel.openPlan(planId);
    chat.addNote('Swapped in $name');
  } on PlanFieldError catch (e) {
    if (e.field != 'offerId' || !context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    sendFromPanel(context, ref, chatKey, 'Swap $name into my plan', about: MessageAbout(planId: planId));
  } on PlanFailure catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } on Object catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(describeApiError(e))));
  }
}
