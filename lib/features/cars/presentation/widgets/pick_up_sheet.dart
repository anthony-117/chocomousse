import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/cars/application/car_providers.dart';
import 'package:chocomousse/features/cars/data/car_models.dart';
import 'package:chocomousse/features/cars/presentation/widgets/car_texts.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/presentation/widgets/offers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// What the "Pick-up and driver" sheet returns.
typedef PickUpChoice = ({PickUpPlace place, int driverAge});

/// Opens the pick-up and driver sheet (C3). Returns the choice to apply, or null when it is dismissed.
Future<PickUpChoice?> showPickUpSheet(
  BuildContext context, {
  required String destinationId,
  required PickUpPlace place,
  required int driverAge,
  required DateTime from,
  required DateTime to,
}) {
  return showModalBottomSheet<PickUpChoice>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: PickUpForm(destinationId: destinationId, place: place, driverAge: driverAge, from: from, to: to),
      ),
    ),
  );
}

class PickUpForm extends ConsumerStatefulWidget {
  const PickUpForm({
    required this.destinationId,
    required this.place,
    required this.driverAge,
    required this.from,
    required this.to,
    super.key,
  });

  final String destinationId;
  final PickUpPlace place;
  final int driverAge;
  final DateTime from;
  final DateTime to;

  @override
  ConsumerState<PickUpForm> createState() => _PickUpFormState();
}

class _PickUpFormState extends ConsumerState<PickUpForm> {
  late PickUpPlace _place = widget.place;
  late final _age = TextEditingController(text: '${widget.driverAge}');

  @override
  void dispose() {
    _age.dispose();
    super.dispose();
  }

  int? get _ageValue => int.tryParse(_age.text.trim());

  bool get _ageIsValid {
    final age = _ageValue;
    return age != null && age >= TripSettings.minDriverAge && age <= TripSettings.maxDriverAge;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final places = ref.watch(carPlacesProvider(widget.destinationId));
    // The centre needs no request, so it is always offered, even while airports load or when they fail.
    final found = places.value?.places ?? const <PickUpPlace>[];
    final options = [PickUpPlace.centre, ...found.where((p) => p.id != PickUpPlace.centreId)];
    if (!options.any((p) => p.id == _place.id)) options.add(_place);
    final warnings = places.value?.warnings ?? const <String>[];
    final note = _ageIsValid ? driverAgeNote(_ageValue) : null;
    final day = DateFormat('d MMM');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pick-up and driver', style: textTheme.titleLarge),
        const SizedBox(height: AppSpacing.lg),
        Text('Pick-up and return', style: textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final place in options)
              ChoiceChip(
                label: Text(place.label),
                selected: place.id == _place.id,
                onSelected: (_) => setState(() => _place = place),
              ),
            if (places.isLoading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Same place both ways, at 10:00 on ${day.format(widget.from)} and ${day.format(widget.to)}.',
          style: textTheme.bodySmall,
        ),
        if (places.hasError) ...[
          const SizedBox(height: AppSpacing.sm),
          const OfferWarning('Airports could not be loaded. Only the city centre is offered for now.'),
        ],
        for (final warning in warnings) ...[const SizedBox(height: AppSpacing.sm), OfferWarning(warning)],
        const SizedBox(height: AppSpacing.lg),
        Text("Driver's age", style: textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _age,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
          decoration: InputDecoration(
            labelText: 'Age (18–99)',
            errorText: _ageIsValid ? null : 'Enter an age from 18 to 99.',
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (note != null) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.muted),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(note, style: textTheme.bodySmall)),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _ageIsValid ? () => Navigator.pop(context, (place: _place, driverAge: _ageValue!)) : null,
            child: const Text('Show cars'),
          ),
        ),
      ],
    );
  }
}
