import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/skeleton.dart';
import 'package:chocomousse/features/cars/data/car_models.dart';
import 'package:chocomousse/features/cars/presentation/widgets/car_texts.dart';
import 'package:chocomousse/features/destination/presentation/widgets/offers.dart';
import 'package:flutter/material.dart';

/// A rental company's logo, hidden when there is none or it fails to load; the name is always shown next to it.
class CompanyLogo extends StatelessWidget {
  const CompanyLogo({required this.url, super.key});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final src = url;
    if (src == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: SizedBox(
        width: 40,
        height: 20,
        child: Image.network(
          src,
          fit: BoxFit.contain,
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// The company line: logo, score and "Budget · 372 reviews".
class CompanyLine extends StatelessWidget {
  const CompanyLine({required this.company, super.key});

  final RentalCompany company;

  @override
  Widget build(BuildContext context) {
    final rating = company.rating;
    final count = company.reviewCount;
    return Row(
      children: [
        CompanyLogo(url: company.logoUrl),
        if (rating != null) ...[ReviewScore(rating), const SizedBox(width: AppSpacing.sm)],
        Expanded(
          child: Text(
            [company.name, if (rating != null && count != null) formatReviews(count)].join(' · '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// One car in the results (CarCard in Figma). The whole card opens the car.
class CarCard extends StatelessWidget {
  const CarCard({required this.car, required this.days, required this.onOpen, super.key});

  final CarOffer car;
  final int days;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final price = car.price;

    return Material(
      color: context.palette.bgSurface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: context.palette.borderDefault),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 120,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Car photos are cut-outs on white, so they fit inside the box rather than fill it.
                  ColoredBox(
                    color: context.palette.bgSurface,
                    child: OfferPhoto(url: car.photoUrl, fit: BoxFit.contain),
                  ),
                  if (car.sponsored) const Positioned(left: AppSpacing.md, top: AppSpacing.md, child: _AdBadge()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(carTitle(car), style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(carSpecs(car), style: textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.sm),
                  CompanyLine(company: car.company),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.place_outlined, size: 14, color: context.palette.textSecondary),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(child: Text(pickUpLine(car.pickUp), style: textTheme.bodySmall)),
                    ],
                  ),
                  if (car.freeCancellation ?? false) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const OfferTag(icon: Icons.check, label: 'Free cancellation'),
                  ],
                  const Divider(height: AppSpacing.xl),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
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
                              '${daysLabel(days)} · ${formatMoney(price.perDay, price.currency)} a day · '
                              '${price.payNow ? 'pay now' : 'pay at pick-up'}',
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text('Booking.com', style: textTheme.labelSmall?.copyWith(color: context.palette.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdBadge extends StatelessWidget {
  const _AdBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: context.palette.bgApp,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: context.palette.borderDefault),
      ),
      child: Text('Ad', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.palette.textSecondary)),
    );
  }
}

/// Empty car cards while cars load, or still ones after a failure.
class CarCardPlaceholders extends StatelessWidget {
  const CarCardPlaceholders({this.count = 3, this.animate = true, super.key});

  final int count;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          SkeletonBox(height: 190, radius: AppRadius.md, animate: animate),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
