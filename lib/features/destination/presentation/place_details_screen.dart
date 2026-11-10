import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/skeleton.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/data/models.dart';
import 'package:chocomousse/features/destination/presentation/widgets/common.dart';
import 'package:chocomousse/features/destination/presentation/widgets/place_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Place details (design 13): photo, description, address, opening hours, website.
class PlaceDetailsScreen extends ConsumerWidget {
  const PlaceDetailsScreen({required this.placeId, super.key});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = ref.watch(placeDetailsProvider(placeId));

    return place.when(
      loading: () => const _DetailsPlaceholder(),
      error: (e, _) => _DetailsPlaceholder(
        banner: ErrorRetry(error: e, onRetry: () => ref.invalidate(placeDetailsProvider(placeId))),
      ),
      data: (p) => _Details(place: p),
    );
  }
}

/// The details layout with empty boxes, while the place loads or after it failed ([banner] set).
class _DetailsPlaceholder extends StatelessWidget {
  const _DetailsPlaceholder({this.banner});

  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final side = wide ? 64.0 : AppSpacing.xl;
    final animate = banner == null;

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: wide ? 64 : 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 280,
                    width: double.infinity,
                    child: DecoratedBox(decoration: BoxDecoration(gradient: photoGradient(context))),
                  ),
                  const SafeArea(
                    child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: BackCircleButton(onDark: true)),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(side, AppSpacing.xl, side, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (banner != null) ...[banner!, const SizedBox(height: AppSpacing.lg)],
                    SkeletonBox(width: 220, height: 28, animate: animate),
                    const SizedBox(height: AppSpacing.sm),
                    SkeletonBox(width: 120, height: 12, animate: animate),
                    const SizedBox(height: AppSpacing.lg),
                    SkeletonBox(height: 72, animate: animate),
                    const SizedBox(height: AppSpacing.lg),
                    SkeletonBox(height: 110, radius: AppRadius.lg, animate: animate),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final side = wide ? 64.0 : AppSpacing.xl;
    final meta = [place.kind, place.priceLevel].whereType<String>().join(' · ');

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: wide ? 64 : 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 280,
                    width: double.infinity,
                    child: place.imageUrl == null
                        ? DecoratedBox(decoration: BoxDecoration(gradient: photoGradient(context)))
                        : Image.network(
                            place.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                DecoratedBox(decoration: BoxDecoration(gradient: photoGradient(context))),
                          ),
                  ),
                  const SafeArea(
                    child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: BackCircleButton(onDark: true)),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(side, AppSpacing.xl, side, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.name, style: textTheme.headlineSmall),
                    if (meta.isNotEmpty) Text(meta, style: textTheme.bodySmall),
                    if (place.rating != null) RatingLine(rating: place.rating!, count: place.ratingCount),
                    if (place.description != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        place.description!,
                        style: textTheme.bodyLarge?.copyWith(color: context.palette.textSecondary),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _InfoCard(place: place),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Data: ${place.source}', style: textTheme.labelSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rows = <Widget>[
      if (place.address != null) _row(context, Icons.place_outlined, place.address!),
      for (final line in place.openingHours) _row(context, Icons.schedule_outlined, line),
      if (place.website != null)
        _row(context, Icons.language_outlined, place.website!, onTap: () => _copy(context, place.website!)),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: context.palette.bgApp, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: DefaultTextStyle(
        style: textTheme.bodyLarge!,
        child: Column(children: rows),
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String text, {VoidCallback? onTap}) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.palette.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
          if (onTap != null) Icon(Icons.copy_outlined, size: 16, color: context.palette.textSecondary),
        ],
      ),
    ),
  );

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
    }
  }
}
