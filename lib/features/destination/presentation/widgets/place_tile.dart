import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/skeleton.dart';
import 'package:chocomousse/features/destination/data/models.dart';
import 'package:chocomousse/features/destination/presentation/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Row for an attraction or restaurant (design 05 / W2).
class PlaceTile extends StatelessWidget {
  const PlaceTile({required this.place, required this.onTap, super.key});

  final Place place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final meta = [place.kind, place.priceLevel].whereType<String>().join(' · ');

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            _Thumb(imageUrl: place.imageUrl),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name, style: textTheme.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (meta.isNotEmpty)
                    Text(meta, style: textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (place.rating != null) RatingLine(rating: place.rating!, count: place.ratingCount),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.palette.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Empty rows in the shape of [PlaceTile], for a list that has not arrived.
class PlaceTilePlaceholders extends StatelessWidget {
  const PlaceTilePlaceholders({this.count = 3, this.animate = true, super.key});

  final int count;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                SkeletonBox(width: 64, height: 64, radius: AppRadius.md + 4, animate: animate),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 160, animate: animate),
                      const SizedBox(height: AppSpacing.sm),
                      SkeletonBox(width: 100, height: 12, animate: animate),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class RatingLine extends StatelessWidget {
  const RatingLine({required this.rating, this.count, super.key});

  final double rating;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final reviews = count == null ? '' : ' · ${NumberFormat.compact().format(count)} reviews';
    return Text(
      '★ ${rating.toStringAsFixed(1)}$reviews',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.palette.statusWarning),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(decoration: BoxDecoration(gradient: photoGradient(context)));
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md + 4),
      child: SizedBox(
        width: 64,
        height: 64,
        child: imageUrl == null
            ? placeholder
            : Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder),
      ),
    );
  }
}

/// Row for an event during the trip.
class EventTile extends StatelessWidget {
  const EventTile({required this.event, super.key});

  final TravelEvent event;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final when = [DateFormat('EEE d MMM').format(event.date), event.time].whereType<String>().join(' · ');
    final details = [
      when,
      event.venue,
      if (event.priceFrom != null) 'from ${event.priceFrom}',
    ].whereType<String>().join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: context.palette.bgApp, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(event.name, style: textTheme.labelLarge),
          Text(details, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}
