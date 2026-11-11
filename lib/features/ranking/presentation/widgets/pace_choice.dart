import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:flutter/material.dart';

/// Pace (I0, P2): how full the itinerary's days are. It shapes the plan only, never the rankings.
class PaceChoice extends StatelessWidget {
  const PaceChoice({required this.value, required this.onChanged, super.key});

  final Pace value;
  final ValueChanged<Pace> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pace', style: textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<Pace>(
            segments: [for (final pace in Pace.values) ButtonSegment(value: pace, label: Text(pace.label))],
            selected: {value},
            showSelectedIcon: false,
            onSelectionChanged: (selected) => onChanged(selected.single),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${value.placesPerDay} places a day, plus lunch and dinner. '
          '${Pace.relaxed.label} is ${Pace.relaxed.placesPerDay}, ${Pace.packed.label} is ${Pace.packed.placesPerDay}. '
          "Pace shapes the itinerary only; it doesn't change the rankings.",
          style: textTheme.bodySmall?.copyWith(color: context.palette.textSecondary),
        ),
      ],
    );
  }
}
