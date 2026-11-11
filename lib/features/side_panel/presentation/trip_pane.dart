import 'dart:async';

import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/core/widgets/cards/plan_card_tile.dart';
import 'package:chocomousse/features/chat/application/chat_controller.dart';
import 'package:chocomousse/features/chat/application/chat_trip.dart';
import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/chat/presentation/trip_sheets.dart';
import 'package:chocomousse/features/chat/presentation/widgets/card_views.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/itinerary/presentation/widgets/plan_texts.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/pace_choice.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/preferences_form.dart';
import 'package:chocomousse/features/side_panel/application/panel_chat.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:chocomousse/features/side_panel/presentation/map_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a chat found, by kind, for "This chat": the cards and the most a step found ("Hotels · 48").
List<(CardKind, int, AssistantCard)> foundByKind(
  List<AssistantCard> cards,
  Iterable<({List<AssistantCard> cards, int? total})> steps,
) => [
  for (final kind in CardKind.values)
    if (kind != CardKind.plan && kind != CardKind.facts)
      if (cards.where((c) => CardKind.of(c) == kind).toList() case final ofKind when ofKind.isNotEmpty)
        (
          kind,
          [
            ofKind.length,
            for (final step in steps)
              if (step.cards.any((c) => CardKind.of(c) == kind)) ?step.total,
          ].reduce((a, b) => a > b ? a : b),
          ofKind.first,
        ),
];

/// The Trip pane (spec 008 US3): the chat's trip, preferences, pace and budget, which the next messages use;
/// Rebuild plan, which rebuilds the open plan with them; and what this chat built and found.
class TripPane extends ConsumerStatefulWidget {
  const TripPane({required this.chatKey, super.key});

  final String chatKey;

  @override
  ConsumerState<TripPane> createState() => _TripPaneState();
}

class _TripPaneState extends ConsumerState<TripPane> {
  bool _rebuilding = false;
  String? _error;
  late final _budget = TextEditingController(text: _budgetText(ref.read(chatTripProvider).trip.tripBudget));

  static String _budgetText(num? budget) => budget == null ? '' : budget.round().toString();

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  ChatTripController get _chips => ref.read(chatTripProvider.notifier);

  Future<void> _rebuild(String planId) async {
    final chips = ref.read(chatTripProvider);
    final trip = chips.trip;
    setState(() {
      _rebuilding = true;
      _error = null;
    });
    try {
      await ref
          .read(planActionsProvider)
          .rebuild(
            planId,
            RebuildRequest(
              from: trip.from,
              to: trip.to,
              adults: trip.adults,
              originId: trip.originId,
              preferences: chips.preferences.isEmpty ? null : chips.preferences,
              pace: chips.pace,
              tripBudget: trip.tripBudget,
            ),
            city: trip.destinationName ?? 'this city',
          );
      ref.read(sidePanelProvider(widget.chatKey).notifier).openPlan(planId);
    } on PlanFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object catch (e) {
      if (mounted) setState(() => _error = describeApiError(e));
    } finally {
      if (mounted) setState(() => _rebuilding = false);
    }
  }

  void _setBudget(String text) {
    final trip = ref.read(chatTripProvider).trip;
    final value = num.tryParse(text.trim());
    _chips.setTrip(
      ChatTrip(
        destinationId: trip.destinationId,
        destinationName: trip.destinationName,
        from: trip.from,
        to: trip.to,
        adults: trip.adults,
        originId: trip.originId,
        originName: trip.originName,
        passport: trip.passport,
        currency: trip.currency,
        tripBudget: value != null && value > 0 ? value : null,
      ),
    );
  }

  Future<void> _pickOrigin() async {
    final picked = await showDialog<({String id, String name})>(
      context: context,
      builder: (_) => const _OriginDialog(),
    );
    if (picked == null || !mounted) return;
    _chips.setTrip(ref.read(chatTripProvider).trip.copyWith(originId: picked.id, originName: picked.name));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final chips = ref.watch(chatTripProvider);
    final trip = chips.trip;
    final panel = ref.watch(sidePanelProvider(widget.chatKey));
    final chat = ref.watch(chatProvider(chatOfPanel(widget.chatKey)));
    final cards = chatCards(chat);
    final plans = cards.whereType<PlanCard>().toList();
    final found = foundByKind(cards, [
      for (final m in chat.messages)
        for (final s in m.steps) (cards: s.cards, total: s.total),
    ]);
    final from = trip.from;
    final to = trip.to;
    final adults = trip.adults ?? 1;
    final planId = panel.planId;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Text(text.toUpperCase(), style: AppText.micro.copyWith(color: palette.textTertiary, letterSpacing: 0.5)),
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text('Your trip', style: AppText.serifTitle.copyWith(color: palette.textPrimary)),
        Text('The next messages of this chat use these.', style: AppText.small.copyWith(color: palette.textSecondary)),
        const SizedBox(height: AppSpacing.md),
        _Row(
          icon: AppIcons.pin,
          label: 'City',
          value: trip.destinationName ?? 'Not set',
          onTap: () => unawaited(showTripEditor(context)),
        ),
        _Row(
          icon: AppIcons.calendar,
          label: 'Dates',
          value: from != null && to != null ? planDates(from, to) : 'Not set',
          onTap: () => unawaited(showTripEditor(context)),
        ),
        _Row(
          icon: AppIcons.users,
          label: 'Adults',
          value: '$adults',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Fewer adults',
                onPressed: adults > 1 ? () => _chips.setTrip(trip.copyWith(adults: adults - 1)) : null,
                icon: const Icon(Icons.remove, size: 18),
              ),
              IconButton(
                tooltip: 'More adults',
                onPressed: adults < 9 ? () => _chips.setTrip(trip.copyWith(adults: adults + 1)) : null,
                icon: const Icon(Icons.add, size: 18),
              ),
            ],
          ),
        ),
        _Row(
          icon: AppIcons.plane,
          label: 'Departure city',
          value: trip.originName ?? 'Not set',
          onTap: () => unawaited(_pickOrigin()),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: TextField(
            controller: _budget,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Trip budget',
              helperText: 'For the whole trip, in ${trip.currency ?? 'your currency'}',
            ),
            onChanged: _setBudget,
          ),
        ),
        heading('Preferences'),
        for (final c in Criterion.values)
          LevelSlider(
            criterion: c,
            level: levelOfWeight(chips.preferences[c.name]),
            onChanged: (level) => _chips.setPreferences({...chips.preferences, c.name: level.weight}),
          ),
        const SizedBox(height: AppSpacing.md),
        PaceChoice(value: chips.pace, onChanged: _chips.setPace),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: planId == null || _rebuilding ? null : () => unawaited(_rebuild(planId)),
          child: _rebuilding
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: AppSpacing.sm),
                    Text('Rebuilding…'),
                  ],
                )
              : const Text('Rebuild plan'),
        ),
        if (planId == null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Open a plan to rebuild it with these values.',
              style: AppText.small.copyWith(color: palette.textSecondary),
            ),
          ),
        if (_error case final error?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(error, style: AppText.small.copyWith(color: palette.statusWarning)),
          ),
        if (plans.isNotEmpty || found.isNotEmpty) ...[
          heading('This chat'),
          for (final plan in plans)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: PlanCardTile(
                plan: plan.plan,
                selected: panel.pane == PanelPane.plan && panel.planId == plan.plan.id,
                onOpen: () => ref.read(sidePanelProvider(widget.chatKey).notifier).openPlan(plan.plan.id),
              ),
            ),
          for (final (kind, count, first) in found)
            _Row(
              icon: switch (kind) {
                CardKind.flight => AppIcons.plane,
                CardKind.hotel => AppIcons.bed,
                CardKind.car => AppIcons.car,
                CardKind.event => AppIcons.ticket,
                _ => AppIcons.landmark,
              },
              label: '${_kindName(kind)} · $count',
              value: '',
              onTap: () => ref.read(sidePanelProvider(widget.chatKey).notifier).openCard(first),
            ),
        ],
      ],
    );
  }

  static String _kindName(CardKind kind) => switch (kind) {
    CardKind.flight => 'Flights',
    CardKind.hotel => 'Hotels',
    CardKind.car => 'Cars',
    CardKind.place => 'Places',
    CardKind.event => 'Events',
    CardKind.plan => 'Plans',
    CardKind.facts => 'Travel facts',
  };
}

/// A line of the Trip pane: an icon, the label, the value, and a tap or a trailing control.
class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value, this.onTap, this.trailing});

  final AppIcons icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            AppIcon(icon, size: 18, color: palette.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(label, style: AppText.body.copyWith(color: palette.textPrimary)),
            ),
            if (value.isNotEmpty)
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: AppText.bodyStrong.copyWith(color: palette.textPrimary),
                ),
              ),
            ?trailing,
            if (onTap != null) AppIcon(AppIcons.chevronRight, size: 16, color: palette.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Picks the departure city by name.
class _OriginDialog extends ConsumerStatefulWidget {
  const _OriginDialog();

  @override
  ConsumerState<_OriginDialog> createState() => _OriginDialogState();
}

class _OriginDialogState extends ConsumerState<_OriginDialog> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim();
    final results = q.length < 2 ? null : ref.watch(destinationSearchProvider(q));
    return AlertDialog(
      title: const Text('Departure city'),
      content: SizedBox(
        width: 360,
        height: 320,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(hintText: 'City'),
              onChanged: (text) => setState(() => _q = text),
            ),
            Expanded(
              child: switch (results) {
                null => const SizedBox.shrink(),
                AsyncData(:final value) => ListView(
                  children: [
                    for (final city in value)
                      ListTile(
                        title: Text(city.name),
                        subtitle: Text(city.countryName),
                        onTap: () => Navigator.of(context).pop((id: city.id, name: city.name)),
                      ),
                  ],
                ),
                AsyncError() => const Center(child: Text("Couldn't search cities.")),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))],
    );
  }
}
