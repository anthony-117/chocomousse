import 'dart:async';

import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/links/link_opener.dart';
import 'package:chocomousse/core/widgets/page_frame.dart';
import 'package:chocomousse/features/cars/data/car_models.dart';
import 'package:chocomousse/features/cars/presentation/widgets/car_card.dart';
import 'package:chocomousse/features/cars/presentation/widgets/car_texts.dart';
import 'package:chocomousse/features/destination/presentation/widgets/common.dart';
import 'package:chocomousse/features/destination/presentation/widgets/offers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the list hands to the details screen: the tapped car and the search it came from.
/// The API has no single-car endpoint, so the details are shown from this (spec FR-010).
class CarDetailsArgs {
  const CarDetailsArgs({required this.car, required this.results});

  final CarOffer car;
  final CarResults results;
}

/// One car, with the way to find it on Booking.com (design C4).
class CarDetailsScreen extends ConsumerWidget {
  const CarDetailsScreen({required this.args, super.key});

  final CarDetailsArgs args;

  Future<void> _open(BuildContext context, WidgetRef ref, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await ref.read(linkOpenerProvider)(url);
    if (!opened) messenger.showSnackBar(const SnackBar(content: Text('Could not open Booking.com.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final car = args.car;
    return PageFrame(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _Details(
              car: car,
              results: args.results,
              onBook: () => unawaited(_open(context, ref, car.bookingUrl)),
            ),
          ),
        ),
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.car, required this.results, required this.onBook});

  final CarOffer car;
  final CarResults results;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pickUp = car.pickUp;
    final address = [?pickUp.address, '${kmLabel(pickUp.distanceKm)} from centre'].join(' · ');
    final where = [pickUp.name, if (pickUp.type != PickUpType.other) pickUp.type.label].join(' · ');
    final specs = [
      if (car.gearbox case final gearbox?) (Icons.settings_outlined, gearbox.label),
      if (car.seats case final seats?) (Icons.event_seat_outlined, '$seats seats'),
      if (car.doors case final doors?) (Icons.sensor_door_outlined, '$doors doors'),
      if (car.bags case final bags?) (Icons.luggage_outlined, bags == 1 ? '1 checked bag' : '$bags checked bags'),
      if (car.airCon ?? false) (Icons.ac_unit, 'Air conditioning'),
    ];
    final deposit = car.deposit;
    final excess = car.damageExcess;
    final fuel = car.fuelPolicy;
    final goodToKnow = [
      if (deposit != null) ('Deposit', '${formatAmount(deposit)}, held on a credit card at pick-up'),
      if (excess != null) ('Damage excess', '${formatAmount(excess)}, the most you pay if the car is damaged'),
      if (fuel != null) ('Fuel', fuelPolicyText(fuel)),
      ('Payment', car.price.payNow ? 'Pay now on Booking.com' : 'Pay at pick-up'),
    ];
    final mileage = car.unlimitedMileage ?? false ? 'Unlimited km' : car.mileage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: SizedBox(
            height: 220,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: OfferPhoto(url: car.photoUrl, fit: BoxFit.contain),
                  ),
                ),
                const Positioned(left: AppSpacing.lg, top: AppSpacing.lg, child: BackCircleButton()),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        for (final warning in results.warnings) ...[OfferWarning(warning), const SizedBox(height: AppSpacing.md)],
        Text(carTitle(car), style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        CompanyLine(company: car.company),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.place_outlined, size: 16, color: AppColors.muted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(where, style: textTheme.labelLarge),
                  Text(address, style: textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            Chip(
              avatar: const Icon(Icons.directions_car_outlined, size: 16, color: AppColors.primary),
              label: Text(car.size),
            ),
            if (car.freeCancellation ?? false) const OfferTag(icon: Icons.check, label: 'Free cancellation'),
            if (mileage != null) OfferTag(icon: Icons.speed, label: mileage),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _DayTile(label: 'Pick-up', value: rentalDay(results.from)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _DayTile(label: 'Return', value: rentalDay(results.to)),
            ),
          ],
        ),
        if (specs.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text('The car', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final (icon, label) in specs)
                Chip(
                  avatar: Icon(icon, size: 16, color: AppColors.muted),
                  label: Text(label),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text('Good to know', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final (label, value) in goodToKnow)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 120, child: Text(label, style: textTheme.labelLarge)),
                Expanded(
                  child: Text(value, style: textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        _PriceBox(car: car, results: results, onBook: onBook),
      ],
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: AppColors.muted),
              const SizedBox(width: AppSpacing.xs),
              Text(label, style: textTheme.labelSmall?.copyWith(color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _PriceBox extends StatelessWidget {
  const _PriceBox({required this.car, required this.results, required this.onBook});

  final CarOffer car;
  final CarResults results;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final price = car.price;
    final checkedAt = results.pricesFetchedAt;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final amount = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: formatMoney(price.total, price.currency),
                      style: textTheme.titleLarge,
                      children: [TextSpan(text: '  total', style: textTheme.bodySmall)],
                    ),
                  ),
                  Text(
                    '${daysLabel(results.days)} · ${formatMoney(price.perDay, price.currency)} a day',
                    style: textTheme.bodySmall,
                  ),
                ],
              );
              final book = FilledButton(onPressed: onBook, child: const Text('Search on Booking.com'));
              return constraints.maxWidth >= 380
                  ? Row(
                      children: [
                        Expanded(child: amount),
                        const SizedBox(width: AppSpacing.md),
                        book,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        amount,
                        const SizedBox(height: AppSpacing.md),
                        book,
                      ],
                    );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Driver ${results.driverAge}.'
            '${checkedAt == null ? '' : ' ${results.isSavedPrice ? 'Saved' : 'Checked'} ${describeCheckedAt(checkedAt)}.'}'
            ' Booking.com opens its search for these dates and this place; find this car there, then book and pay '
            'on Booking.com.',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
