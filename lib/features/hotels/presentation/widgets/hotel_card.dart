import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/skeleton.dart';
import 'package:chocomousse/features/destination/presentation/widgets/offers.dart';
import 'package:chocomousse/features/hotels/data/hotel_models.dart';
import 'package:flutter/material.dart';

/// Stars as small coral icons. Callers hide it when a hotel has none.
class HotelStars extends StatelessWidget {
  const HotelStars(this.count, {this.size = 12, super.key});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count stars',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [for (var i = 0; i < count; i++) Icon(Icons.star_rounded, size: size, color: AppColors.accent)],
        ),
      ),
    );
  }
}

/// One hotel in the results (HotelCard in Figma). The whole card opens the hotel.
class HotelCard extends StatelessWidget {
  const HotelCard({
    required this.hotel,
    required this.nights,
    required this.destinationName,
    required this.onOpen,
    super.key,
  });

  final HotelOffer hotel;
  final int nights;
  final String destinationName;
  final VoidCallback onOpen;

  static String _km(double km) => km < 10 ? km.toStringAsFixed(1) : km.round().toString();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final price = hotel.price;
    final stars = hotel.stars;
    final score = hotel.reviewScore;
    final count = hotel.reviewCount;

    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 148,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  OfferPhoto(url: hotel.photoUrl),
                  if (hotel.nearCity)
                    Positioned(
                      left: AppSpacing.md,
                      top: AppSpacing.md,
                      child: _NearBadge('${_km(hotel.distanceKm)} km from $destinationName'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hotel.name, style: textTheme.titleMedium),
                  if (stars != null || score != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (stars != null && stars > 0) HotelStars(stars),
                        if (score != null) ReviewScore(score),
                        if (score != null && count != null) Text(formatReviews(count), style: textTheme.bodySmall),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 14, color: AppColors.muted),
                      const SizedBox(width: AppSpacing.xs),
                      Text('${_km(hotel.distanceKm)} km from centre', style: textTheme.bodySmall),
                    ],
                  ),
                  if (hotel.freeCancellation ?? false) ...[
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
                              '${nights == 1 ? '1 night' : '$nights nights'} · '
                              '${formatMoney(price.perNight, price.currency)} a night',
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text('Booking.com', style: textTheme.labelSmall?.copyWith(color: AppColors.muted)),
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

class _NearBadge extends StatelessWidget {
  const _NearBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place_outlined, size: 12, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary)),
        ],
      ),
    );
  }
}

/// Empty hotel cards while hotels load, or still ones after a failure.
class HotelCardPlaceholders extends StatelessWidget {
  const HotelCardPlaceholders({this.animate = true, super.key});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          SkeletonBox(height: 300, radius: AppRadius.md, animate: animate),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
