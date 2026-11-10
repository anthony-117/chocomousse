import 'dart:async';

import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/core/widgets/cards/pin_preview.dart';
import 'package:chocomousse/core/widgets/cards/result_row.dart';
import 'package:chocomousse/features/destination/presentation/widgets/offers.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/presentation/change_offer_screen.dart';
import 'package:chocomousse/features/itinerary/presentation/plan_why_view.dart';
import 'package:chocomousse/features/itinerary/presentation/widgets/day_view.dart';
import 'package:chocomousse/features/itinerary/presentation/widgets/plan_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The items of a plan's days that have a place, numbered by day. Their ids are `day:{n}:{i}`.
List<MapPin> planPins(Plan plan) => [
  for (final day in plan.days)
    for (final (i, item) in day.items.indexed)
      if (item.ref case ItemRef(:final lat?, :final lng?))
        MapPin(
          id: 'day:${day.number}:$i',
          lat: lat,
          lng: lng,
          kind: PinKind.planDay,
          label: 'Day ${day.number} · ${item.name}',
          number: day.number,
        ),
];

/// The plan in the chat's side panel (spec 008 US1, Figma "Side panel / Plan"): the header, three summary tiles,
/// the tabs Days, Hotel, Flight, Car, Map and Costs, and the bottom bar.
class EmbeddedPlanView extends ConsumerStatefulWidget {
  const EmbeddedPlanView({required this.plan, this.onAskAboutDay, super.key});

  final Plan plan;

  /// "Ask to change this day…" (spec 008 US3); off until then.
  final ValueChanged<int>? onAskAboutDay;

  @override
  ConsumerState<EmbeddedPlanView> createState() => _EmbeddedPlanViewState();
}

class _EmbeddedPlanViewState extends ConsumerState<EmbeddedPlanView> {
  int? _day;
  bool _saving = false;

  Plan get plan => widget.plan;

  Future<void> _toggleStatus() async {
    final messenger = ScaffoldMessenger.of(context);
    final next = plan.status == PlanStatus.planned ? PlanStatus.draft : PlanStatus.planned;
    setState(() => _saving = true);
    try {
      await ref.read(planActionsProvider).setStatus(plan.id, next);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeApiError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share() async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: '/plans/${plan.id}'));
    messenger.showSnackBar(const SnackBar(content: Text('Link to the plan copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final days = plan.days;
    final chosen = days.where((d) => d.number == _day).firstOrNull ?? days.firstOrNull;
    final from = plan.flight?.offer.originAirport;
    final subtitle = [planDates(plan.from, plan.to), adults(plan.adults), if (from != null) 'from $from'].join(' · ');
    final match = plan.match;
    final budget = plan.tripBudget;
    final total = formatMoney(plan.total.amount, plan.total.currency);
    final onAsk = widget.onAskAboutDay;

    return DefaultTabController(
      length: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.md, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              plan.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.serifTitle.copyWith(color: palette.textPrimary),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _StatusPill(plan.status),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(subtitle, style: AppText.small.copyWith(color: palette.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Share',
                  onPressed: () => unawaited(_share()),
                  icon: AppIcon(AppIcons.share, color: palette.textSecondary),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: AppIcon(AppIcons.more, color: palette.textSecondary),
                  onSelected: (_) => unawaited(context.push('/plans/${plan.id}')),
                  itemBuilder: (_) => const [PopupMenuItem(value: 'open', child: Text('Open full page'))],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
            child: Row(
              children: [
                Expanded(
                  child: _Tile(
                    label: 'MATCH',
                    value: match == null ? '—' : '${match.percent}%',
                    note: match?.parts.map((p) => '${p.part.label} ${p.percent}%').join(' · ') ?? '',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Tile(
                    label: 'TOTAL',
                    value: total,
                    note: budget == null ? 'No budget set' : 'of ${formatMoney(budget, plan.total.currency)}',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Tile(label: 'PACE', value: plan.pace.label, note: '${plan.pace.placesPerDay} places a day'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Days'),
              Tab(text: 'Hotel'),
              Tab(text: 'Flight'),
              Tab(text: 'Car'),
              Tab(text: 'Map'),
              Tab(text: 'Costs'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _scroll([
                  if (chosen == null)
                    Text('This plan has no days.', style: AppText.body.copyWith(color: palette.textSecondary))
                  else ...[
                    DayChips(days: days, selected: chosen.number, onSelected: (n) => setState(() => _day = n)),
                    const SizedBox(height: AppSpacing.md),
                    DayCard(day: chosen, onItem: (_) => null),
                  ],
                ]),
                _scroll([_offer(context, OfferKind.hotel)]),
                _scroll([_offer(context, OfferKind.flight)]),
                _scroll([_offer(context, OfferKind.car)]),
                _scroll([
                  if (planPins(plan) case final pins when pins.isNotEmpty)
                    PinPreview(pins: pins, onSelect: (id) => setState(() => _day = int.tryParse(id.split(':')[1])))
                  else
                    Text(
                      'No place of this plan has a position yet.',
                      style: AppText.body.copyWith(color: palette.textSecondary),
                    ),
                ]),
                _scroll([PlanWhyView(plan: plan)]),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: palette.borderDefault)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onAsk == null || chosen == null ? null : () => onAsk(chosen.number),
                      child: const Text('Ask to change this day…', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: _saving ? null : () => unawaited(_toggleStatus()),
                    child: Text(plan.status == PlanStatus.planned ? 'Mark as draft' : 'Mark as planned'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scroll(List<Widget> children) => ListView(padding: const EdgeInsets.all(AppSpacing.xl), children: children);

  Widget _offer(BuildContext context, OfferKind kind) {
    final change = TextButton(
      onPressed: () => openChange(context, plan, kind),
      child: Text(switch (kind) {
        OfferKind.car when plan.car == null => 'Add a car',
        _ => 'Change',
      }),
    );
    final row = switch (kind) {
      OfferKind.hotel => switch (plan.hotel?.offer) {
        final hotel? => ResultRow(
          icon: AppIcons.bed,
          title: hotel.name,
          subtitle: [if (hotel.stars case final s?) '$s★', nights(plan.nights)].join(' · '),
          price: formatMoney(hotel.price.total, hotel.price.currency),
          match: plan.hotel?.ranked.match,
        ),
        null => null,
      },
      OfferKind.flight => switch (plan.flight?.offer) {
        final flight? => ResultRow(
          icon: AppIcons.plane,
          title: '${flight.originAirport} → ${flight.destinationAirport}',
          subtitle: flight.stops == 0 ? 'Direct' : '${flight.stops} stops',
          price: formatMoney(flight.amount, flight.currency),
          match: plan.flight?.ranked.match,
        ),
        null => null,
      },
      OfferKind.car => switch (plan.car?.offer) {
        final car? => ResultRow(
          icon: AppIcons.car,
          title: '${car.model} · ${car.company.name}',
          subtitle: 'Pick up at ${car.pickUp.name}',
          price: formatMoney(car.price.total, car.price.currency),
          match: plan.car?.ranked.match,
        ),
        null => null,
      },
    };
    final none = switch (kind) {
      OfferKind.hotel => 'No hotel in this plan.',
      OfferKind.flight => 'No flight in this plan.',
      OfferKind.car => 'No car in this plan.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row ?? Text(none, style: AppText.body.copyWith(color: context.palette.textSecondary)),
        Align(alignment: Alignment.centerRight, child: change),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);

  final PlanStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final planned = status == PlanStatus.planned;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: planned ? palette.statusSuccessSoft : palette.bgSubtle,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        status.label,
        style: AppText.smallStrong.copyWith(color: planned ? palette.statusSuccess : palette.textSecondary),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.note});

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: palette.bgSubtle, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.micro.copyWith(color: palette.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodyStrong.copyWith(color: palette.textPrimary),
          ),
          Text(
            note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.small.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}
