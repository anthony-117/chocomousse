import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/destination/presentation/widgets/trip_chips.dart';
import 'package:chocomousse/features/flights/presentation/widgets/departure_city_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// S1's form, also the left column of W1: dates, travellers, departure city, total budget and the six sliders.
/// Dates, travellers and the departure city save at once, as everywhere else. Preferences and the budget go to
/// [onChanged], with `budgetValid` false while the budget field holds something other than a whole number above 0.
class PreferencesForm extends ConsumerStatefulWidget {
  const PreferencesForm({required this.value, required this.onChanged, required this.note, super.key});

  final Preferences value;
  final void Function(Preferences value, {required bool budgetValid}) onChanged;
  final String note;

  @override
  ConsumerState<PreferencesForm> createState() => _PreferencesFormState();
}

class _PreferencesFormState extends ConsumerState<PreferencesForm> {
  late final TextEditingController _budget = TextEditingController(text: widget.value.tripBudget?.toString() ?? '');
  String? _budgetError;

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  void _onBudget(String text) {
    final trimmed = text.trim();
    final amount = int.tryParse(trimmed);
    final valid = trimmed.isEmpty || (amount != null && amount > 0);
    setState(() => _budgetError = valid ? null : 'Enter an amount above 0, or leave it empty.');
    widget.onChanged(valid ? widget.value.withTripBudget(amount) : widget.value, budgetValid: valid);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final trip = ref.watch(tripSettingsProvider);
    final day = DateFormat('d MMM');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _FieldBox(
                label: 'Dates',
                value: '${day.format(trip.from)} – ${day.format(trip.to)}',
                onTap: () => pickTripDates(context, ref),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _FieldBox(
                label: 'Travellers',
                value: adultsLabel(trip.adults),
                onTap: () => showAdultsPicker(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const DepartureCityField(),
        const SizedBox(height: AppSpacing.lg),
        Text('Total budget (optional)', style: textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _budget,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
          decoration: InputDecoration(
            hintText: 'No limit',
            suffixText: trip.currency,
            errorText: _budgetError,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: _onBudget,
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(color: context.palette.bgApp, borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What matters most?', style: textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              for (final criterion in Criterion.values)
                LevelSlider(
                  criterion: criterion,
                  level: widget.value.of(criterion),
                  onChanged: (level) =>
                      widget.onChanged(widget.value.withLevel(criterion, level), budgetValid: _budgetError == null),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(widget.note, style: textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// One preference: its name, its level and a slider with three stops (spec clarification 2).
class LevelSlider extends StatelessWidget {
  const LevelSlider({required this.criterion, required this.level, required this.onChanged, super.key});

  final Criterion criterion;
  final Level level;
  final ValueChanged<Level> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(child: Text(criterion.label, style: textTheme.bodyMedium)),
              Text(level.label, style: textTheme.bodySmall?.copyWith(color: context.palette.brandPrimary)),
            ],
          ),
        ),
        Slider(
          value: level.index.toDouble(),
          max: (Level.values.length - 1).toDouble(),
          divisions: Level.values.length - 1,
          label: level.label,
          semanticFormatterCallback: (_) => '${criterion.label}: ${level.label}',
          onChanged: (v) => onChanged(Level.values[v.round()]),
        ),
      ],
    );
  }
}

class _FieldBox extends StatelessWidget {
  const _FieldBox({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        Material(
          color: context.palette.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: context.palette.borderDefault),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(child: Text(value, style: textTheme.labelLarge)),
                  Icon(Icons.expand_more, color: context.palette.textSecondary, size: 18),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
