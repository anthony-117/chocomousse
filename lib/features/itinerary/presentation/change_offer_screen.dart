import 'dart:async';

import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/page_frame.dart';
import 'package:chocomousse/features/cars/data/car_models.dart';
import 'package:chocomousse/features/cars/presentation/cars_screen.dart';
import 'package:chocomousse/features/destination/presentation/widgets/offers.dart';
import 'package:chocomousse/features/flights/data/flight_models.dart';
import 'package:chocomousse/features/hotels/data/hotel_models.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/itinerary/presentation/itinerary_screen.dart';
import 'package:chocomousse/features/itinerary/presentation/widgets/plan_texts.dart';
import 'package:chocomousse/features/ranking/data/ranking_models.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/ranked_card.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/ranked_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// The kept ranked list of one kind of a plan (API research R-7). Hotels and flights are never searched again; the
/// first car list runs the car search.
final FutureProviderFamily<Alternatives<Object>, (String, OfferKind)> alternativesProvider = FutureProvider.autoDispose
    .family<Alternatives<Object>, (String, OfferKind)>((ref, key) {
      final repository = ref.watch(planRepositoryProvider);
      final (id, kind) = key;
      return switch (kind) {
        OfferKind.hotel => repository.hotels(id),
        OfferKind.flight => repository.flights(id),
        OfferKind.car => repository.cars(id),
      };
    });

/// Opens I4 for [kind]: a page on phones, a dialog over W4 on wide screens (plan decision 5).
void openChange(BuildContext context, Plan plan, OfferKind kind) {
  if (MediaQuery.sizeOf(context).width < kWideLayoutBreakpoint) {
    unawaited(context.push('/plans/${plan.id}/change/${kind.name}'));
    return;
  }
  unawaited(
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ChangeOfferView(planId: plan.id, kind: kind, onDone: () => Navigator.of(dialogContext).pop()),
          ),
        ),
      ),
    ),
  );
}

/// Change hotel, flight or car (I4) on phones.
class ChangeOfferScreen extends StatelessWidget {
  const ChangeOfferScreen({required this.planId, required this.kind, super.key});

  final String planId;
  final OfferKind kind;

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      children: [
        ChangeOfferView(
          planId: planId,
          kind: kind,
          onDone: () => context.canPop() ? context.pop() : context.go('/plans/$planId'),
        ),
      ],
    );
  }
}

final _when = DateFormat('EEE d MMM · HH:mm');

String _title(OfferKind kind) => switch (kind) {
  OfferKind.hotel => 'hotel',
  OfferKind.flight => 'flight',
  OfferKind.car => 'car',
};

String _noun(OfferKind kind, int n) => '$n ${_title(kind)}${n == 1 ? '' : 's'}';

String _info(OfferKind kind) => switch (kind) {
  OfferKind.hotel => 'Choosing a hotel rebuilds the days around it. Same search, so nothing new is searched.',
  OfferKind.flight =>
    'Choosing a flight rebuilds the first and last days around it. Same search, so nothing new is searched.',
  OfferKind.car => 'Choosing a car adds it to the total. The days stay as they are.',
};

String _stops(int stops) => switch (stops) {
  0 => 'DIRECT',
  1 => '1 STOP',
  _ => '$stops STOPS',
};

/// The kept list, ranked, with the plan's own offer marked "In your plan". Picking another swaps it in and closes.
class ChangeOfferView extends ConsumerStatefulWidget {
  const ChangeOfferView({required this.planId, required this.kind, required this.onDone, super.key});

  final String planId;
  final OfferKind kind;
  final VoidCallback onDone;

  @override
  ConsumerState<ChangeOfferView> createState() => _ChangeOfferViewState();
}

class _ChangeOfferViewState extends ConsumerState<ChangeOfferView> {
  bool _busy = false;
  Object? _error;
  Future<void> Function()? _retry;

  Future<void> _run(Future<void> Function() change) async {
    setState(() {
      _busy = true;
      _error = null;
      _retry = () => _run(change);
    });
    try {
      await change();
      if (mounted) widget.onDone();
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _swap(String offerId) =>
      unawaited(_run(() => ref.read(planActionsProvider).swap(widget.planId, widget.kind, offerId)));

  void _removeCar() => unawaited(_run(() => ref.read(planActionsProvider).removeCar(widget.planId)));

  RankedCardData _card(Plan plan, Object offer, {required bool chosen}) {
    final mark = chosen ? ' · IN YOUR PLAN' : '';
    return switch (offer) {
      final HotelOffer h => RankedCardData(
        id: h.id,
        kind: '${h.stars == null ? 'HOTEL' : 'HOTEL · ${h.stars}★'}$mark',
        title: h.name,
        details:
            '${nights(plan.nights)} · ${h.distanceKm.toStringAsFixed(1)} km from '
            '${h.nearCity ? plan.destinationName : 'the centre'}',
        price: formatMoney(h.price.total, h.price.currency),
        priceLine: '',
        openLabel: '',
      ),
      final FlightFare f => RankedCardData(
        id: f.id,
        kind: 'FLIGHT · ${_stops(f.stops)}$mark',
        title: '${f.originAirport} → ${f.destinationAirport}',
        details: [_when.format(f.departureAt), ?f.dateMatch.label].join(' · '),
        price: formatMoney(f.amount, f.currency),
        priceLine: '',
        openLabel: '',
      ),
      final CarOffer c => RankedCardData(
        id: c.id,
        kind: 'CAR · ${c.size.toUpperCase()}$mark',
        title: '${c.model} · ${c.company.name}',
        details: [?c.gearbox?.label, if (c.seats != null) '${c.seats} seats', c.pickUp.name].join(' · '),
        price: formatMoney(c.price.total, c.price.currency),
        priceLine: '',
        openLabel: '',
      ),
      _ => throw ArgumentError.value(offer, 'offer'),
    };
  }

  String _id(Object offer) => switch (offer) {
    final HotelOffer h => h.id,
    final FlightFare f => f.id,
    final CarOffer c => c.id,
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final kind = widget.kind;
    final key = (widget.planId, kind);
    final plan = ref.watch(planProvider(widget.planId)).value;
    final list = ref.watch(alternativesProvider(key));
    final count = list.value?.items.length;
    final error = _error;
    final retry = _retry;

    final Widget body;
    if (plan == null || list.isLoading) {
      body = kind == OfferKind.car ? const CarSearching() : const RankedCardPlaceholders();
    } else if (list.error case final e?) {
      body = Column(
        children: [
          ErrorRetryBanner(message: describePlanError(e), onRetry: () => ref.invalidate(alternativesProvider(key))),
          const SizedBox(height: AppSpacing.md),
          const RankedCardPlaceholders(animate: false),
        ],
      );
    } else {
      final alternatives = list.requireValue;
      body = Column(
        children: [
          if (alternatives.items.isEmpty) Text('No other ${_title(kind)}s in this plan.', style: textTheme.bodySmall),
          for (final Ranked<Object> item in alternatives.items) ...[
            RankedCard(
              data: _card(plan, item.offer, chosen: _id(item.offer) == alternatives.chosenId),
              match: item.match,
              selected: _id(item.offer) == alternatives.chosenId,
              onTap: _busy
                  ? () {}
                  : () => _id(item.offer) == alternatives.chosenId ? widget.onDone() : _swap(_id(item.offer)),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (kind == OfferKind.car && plan.car != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _busy ? null : _removeCar,
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Remove car'),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const PlansBackButton(),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kind == OfferKind.car && plan?.car == null ? 'Add a car' : 'Change ${_title(kind)}',
                    style: textTheme.headlineSmall,
                  ),
                  Text(
                    count == null ? 'Ranked by your preferences' : 'Ranked by your preferences · ${_noun(kind, count)}',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Text(_info(kind), style: textTheme.bodySmall?.copyWith(color: AppColors.text)),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_busy) ...[const LinearProgressIndicator(), const SizedBox(height: AppSpacing.md)],
        if (error != null && retry != null) ...[
          ErrorRetryBanner(message: describePlanError(error), onRetry: () => unawaited(retry())),
          const SizedBox(height: AppSpacing.md),
        ],
        body,
      ],
    );
  }
}
