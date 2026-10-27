import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/page_frame.dart';
import '../application/destination_providers.dart';
import '../data/models.dart';
import 'widgets/common.dart';
import 'widgets/pin_map.dart';
import 'widgets/place_tile.dart';

/// Attractions and restaurants with a map (designs 05 / W2).
class PlacesScreen extends ConsumerStatefulWidget {
  const PlacesScreen({required this.id, this.initialCategory, super.key});

  final String id;
  final String? initialCategory;

  @override
  ConsumerState<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends ConsumerState<PlacesScreen> {
  late PlaceCategory _category = PlaceCategory.values.asNameMap()[widget.initialCategory] ?? PlaceCategory.attraction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final destination = ref.watch(destinationProvider(widget.id));
    final places = ref.watch(placesProvider((widget.id, _category)));
    final title = destination.value == null ? 'Places' : '${destination.value!.name} · Places';

    return PageFrame(
      children: [
        Row(
          children: [
            const BackCircleButton(),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(title, style: textTheme.headlineSmall)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final c in PlaceCategory.values)
              ChoiceChip(
                label: Text(c.label),
                selected: c == _category,
                onSelected: (_) => setState(() => _category = c),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (destination.value case final d?)
          PinMap(centerLat: d.lat, centerLng: d.lng, places: places.value?.items ?? const []),
        const SizedBox(height: AppSpacing.lg),
        places.when(
          loading: () => const LoadingBlock(),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(placesProvider((widget.id, _category)))),
          data: (result) => result.items.isEmpty
              ? WarningNote(result.warnings.firstOrNull ?? 'Nothing found here yet.')
              : Column(
                  children: [
                    for (final place in result.items)
                      PlaceTile(
                        place: place,
                        onTap: () => context.push('/discover/place/${Uri.encodeComponent(place.id)}'),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
