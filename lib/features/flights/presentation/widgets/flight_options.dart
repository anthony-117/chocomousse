import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/flights/data/flight_models.dart';
import 'package:flutter/material.dart';

/// Round trip or one way, and direct flights only.
class FlightOptions extends StatelessWidget {
  const FlightOptions({
    required this.tripType,
    required this.directOnly,
    required this.onTripTypeChanged,
    required this.onDirectOnlyChanged,
    super.key,
  });

  final FlightTripType tripType;
  final bool directOnly;
  final ValueChanged<FlightTripType> onTripTypeChanged;
  final ValueChanged<bool> onDirectOnlyChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final (type, label) in const [
              (FlightTripType.roundTrip, 'Round trip'),
              (FlightTripType.oneWay, 'One way'),
            ])
              ChoiceChip(label: Text(label), selected: type == tripType, onSelected: (_) => onTripTypeChanged(type)),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Direct only', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: AppSpacing.sm),
            Switch(value: directOnly, onChanged: onDirectOnlyChanged),
          ],
        ),
      ],
    );
  }
}
