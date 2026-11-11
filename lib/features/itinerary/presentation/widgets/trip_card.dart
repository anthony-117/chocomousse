import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/destination/presentation/widgets/offers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/presentation/widgets/plan_texts.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _when = DateFormat('EEE d MMM HH:mm');

String _stops(int stops) => switch (stops) {
  0 => 'Direct',
  1 => '1 stop',
  _ => '$stops stops',
};

String _distance(double km, String city, {required bool nearCity}) =>
    '${km < 10 ? km.toStringAsFixed(1) : km.round()} km from ${nearCity ? city : 'the centre'}';

/// "Your trip" (I1): the flight, the hotel and the car, each with Change or Add, and the total with "Why 91%?".
class TripCard extends StatelessWidget {
  const TripCard({required this.plan, required this.onChange, required this.onWhy, super.key});

  final Plan plan;
  final ValueChanged<OfferKind> onChange;
  final VoidCallback onWhy;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final flight = plan.flight?.offer;
    final hotel = plan.hotel?.offer;
    final car = plan.car?.offer;
    final match = plan.match;
    final total = formatMoney(plan.total.amount, plan.total.currency);

    return PlanPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Your trip', style: textTheme.titleMedium)),
              TextButton(
                onPressed: onWhy,
                child: Text(match == null ? '$total · Cost' : '$total · Why ${match.percent}%?'),
              ),
            ],
          ),
          if (flight != null)
            _OfferRow(
              kind: 'FLIGHT',
              title: '${flight.originAirport} → ${flight.destinationAirport}',
              details: '${_when.format(flight.departureAt)} · ${_stops(flight.stops)}',
              price: formatMoney(flight.amount, flight.currency),
              action: 'Change',
              onAction: () => onChange(OfferKind.flight),
            )
          else
            _OfferRow(
              kind: 'FLIGHT',
              title: 'No flight',
              details: plan.originId == null
                  ? 'Choose where you fly from on Plan your trip to add one'
                  : 'No recent fares for these dates',
              action: plan.originId == null ? null : 'Change',
              onAction: () => onChange(OfferKind.flight),
            ),
          if (hotel != null)
            _OfferRow(
              kind: hotel.stars == null ? 'HOTEL' : 'HOTEL · ${hotel.stars}★',
              title: hotel.name,
              details:
                  '${nights(plan.nights)} · ${_distance(hotel.distanceKm, plan.destinationName, nearCity: hotel.nearCity)}',
              price: formatMoney(hotel.price.total, hotel.price.currency),
              action: 'Change',
              onAction: () => onChange(OfferKind.hotel),
            )
          else
            _OfferRow(
              kind: 'HOTEL',
              title: 'No hotel',
              details: 'Choose one from the ranked hotels',
              action: 'Change',
              onAction: () => onChange(OfferKind.hotel),
            ),
          if (car != null)
            _OfferRow(
              kind: 'CAR · ${car.size.toUpperCase()}',
              title: '${car.model} · ${car.company.name}',
              details: 'Pick up at ${car.pickUp.name}',
              price: formatMoney(car.price.total, car.price.currency),
              action: 'Change',
              onAction: () => onChange(OfferKind.car),
            )
          else
            _OfferRow(
              kind: 'CAR',
              title: 'No car',
              details: 'Add one from the ranked cars',
              price: '—',
              action: 'Add',
              onAction: () => onChange(OfferKind.car),
            ),
        ],
      ),
    );
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({
    required this.kind,
    required this.title,
    required this.details,
    required this.onAction,
    this.price,
    this.action,
  });

  final String kind;
  final String title;
  final String details;
  final String? price;
  final String? action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final price = this.price;
    final action = this.action;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kind, style: textTheme.labelSmall?.copyWith(color: context.palette.textSecondary)),
          Row(
            children: [
              Expanded(child: Text(title, style: textTheme.titleSmall)),
              if (price != null) ...[const SizedBox(width: AppSpacing.sm), Text(price, style: textTheme.titleSmall)],
              if (action != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  ),
                  child: Text(action, semanticsLabel: '$action ${kind.split(' ').first.toLowerCase()}'),
                ),
            ],
          ),
          Text(details, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// White rounded card of the itinerary frames.
class PlanPanel extends StatelessWidget {
  const PlanPanel({required this.child, this.padding = const EdgeInsets.all(AppSpacing.lg), super.key});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: context.palette.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.palette.borderDefault),
      ),
      child: child,
    );
  }
}
