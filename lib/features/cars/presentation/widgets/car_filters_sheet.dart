import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/cars/data/car_models.dart';
import 'package:chocomousse/features/cars/presentation/widgets/car_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The values a search can be filtered on, from the API's `filterOptions`.
typedef CarFilterChoices = ({
  List<FilterOption> sizes,
  List<FilterOption> companies,
  List<FilterOption> pickUpTypes,
  int searched,
});

const CarFilterChoices noCarFilterChoices = (sizes: [], companies: [], pickUpTypes: [], searched: 0);

/// Opens the sort and filter sheet (C2) and returns the filters to apply, or null when it is dismissed.
Future<CarFilters?> showCarFiltersSheet(
  BuildContext context, {
  required CarFilters filters,
  required CarFilterChoices choices,
  required int days,
  required String currency,
}) {
  return showModalBottomSheet<CarFilters>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
          child: CarFiltersForm(
            filters: filters,
            choices: choices,
            days: days,
            currency: currency,
            showTitle: true,
            onApply: (applied) => Navigator.pop(context, applied),
          ),
        ),
      ),
    ),
  );
}

/// Sort and filters, edited as a copy and sent only on "Show cars", so the list doesn't reload on every tap.
/// The phone sheet and the wide side panel both use it.
class CarFiltersForm extends StatefulWidget {
  const CarFiltersForm({
    required this.filters,
    required this.choices,
    required this.days,
    required this.currency,
    required this.onApply,
    this.showTitle = false,
    super.key,
  });

  final CarFilters filters;
  final CarFilterChoices choices;
  final int days;
  final String currency;
  final ValueChanged<CarFilters> onApply;
  final bool showTitle;

  @override
  State<CarFiltersForm> createState() => _CarFiltersFormState();
}

class _CarFiltersFormState extends State<CarFiltersForm> {
  /// Companies shown before "+N more" (C2).
  static const _companiesShown = 6;

  late CarFilters _draft = widget.filters;
  late final _max = TextEditingController(text: widget.filters.maxPrice?.toString() ?? '');
  bool _allCompanies = false;

  @override
  void didUpdateWidget(CarFiltersForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The side panel stays on screen while the list changes, so it follows the applied filters.
    if (oldWidget.filters != widget.filters) _reset(widget.filters);
  }

  @override
  void dispose() {
    _max.dispose();
    super.dispose();
  }

  void _reset(CarFilters filters) => setState(() {
    _draft = filters;
    _max.text = filters.maxPrice?.toString() ?? '';
  });

  static List<T> _toggle<T>(List<T> list, T value, {required bool on}) =>
      on ? [...list, value] : list.where((v) => v != value).toList();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final choices = widget.choices;
    final valid = _draft.maxPriceIsValid;

    Widget group(String title, List<Widget> chips) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: chips),
        ],
      ),
    );

    ChoiceChip choice(String label, {required bool selected, required VoidCallback onTap}) =>
        ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());

    // Companies already chosen stay visible even when they are past the first few.
    final companies = _allCompanies || choices.companies.length <= _companiesShown
        ? choices.companies
        : [
            ...choices.companies.take(_companiesShown),
            ...choices.companies.skip(_companiesShown).where((c) => _draft.companies.contains(c.value)),
          ];
    final hidden = choices.companies.length - companies.length;
    final types = {for (final option in choices.pickUpTypes) PickUpType.parse(option.value)}.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: widget.showTitle ? Text('Sort and filter', style: textTheme.titleLarge) : const SizedBox()),
            TextButton(onPressed: () => _reset(_draft.cleared()), child: const Text('Clear all')),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        group('Sort by', [
          for (final sort in CarSort.values)
            choice(
              sort.label,
              selected: _draft.sort == sort,
              onTap: () => setState(() => _draft = _draft.copyWith(sort: sort)),
            ),
        ]),
        if (choices.sizes.isNotEmpty)
          group('Car size', [
            choice(
              'Any',
              selected: _draft.sizes.isEmpty,
              onTap: () => setState(() => _draft = _draft.copyWith(sizes: [])),
            ),
            for (final size in choices.sizes)
              FilterChip(
                label: Text(size.value),
                selected: _draft.sizes.contains(size.value),
                onSelected: (on) =>
                    setState(() => _draft = _draft.copyWith(sizes: _toggle(_draft.sizes, size.value, on: on))),
              ),
          ]),
        group('Gearbox', [
          for (final gearbox in [null, ...Gearbox.values])
            choice(
              gearbox?.label ?? 'Any',
              selected: _draft.gearbox == gearbox,
              onTap: () => setState(() => _draft = _draft.copyWith(gearbox: () => gearbox)),
            ),
        ]),
        group('Seats', [
          for (final seats in [null, ...carSeatChoices])
            choice(
              seats == null ? 'Any' : '$seats+',
              selected: _draft.minSeats == seats,
              onTap: () => setState(() => _draft = _draft.copyWith(minSeats: () => seats)),
            ),
        ]),
        group('Bags', [
          for (final bags in [null, ...carBagChoices])
            choice(
              bags == null ? 'Any' : '$bags+',
              selected: _draft.minBags == bags,
              onTap: () => setState(() => _draft = _draft.copyWith(minBags: () => bags)),
            ),
        ]),
        Text('Maximum total for ${daysLabel(widget.days)} (${widget.currency})', style: textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _max,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Max',
            hintText: 'Any',
            errorText: valid ? null : 'The maximum must be more than 0.',
          ),
          onChanged: (v) => setState(() => _draft = _draft.copyWith(maxPrice: () => int.tryParse(v.trim()))),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (types.isNotEmpty)
          group('Pick-up place', [
            for (final type in types)
              FilterChip(
                label: Text(type.label),
                selected: _draft.pickUpTypes.contains(type),
                onSelected: (on) =>
                    setState(() => _draft = _draft.copyWith(pickUpTypes: _toggle(_draft.pickUpTypes, type, on: on))),
              ),
          ]),
        if (companies.isNotEmpty)
          group('Rental company', [
            for (final company in companies)
              FilterChip(
                label: Text(company.value),
                selected: _draft.companies.contains(company.value),
                onSelected: (on) => setState(
                  () => _draft = _draft.copyWith(companies: _toggle(_draft.companies, company.value, on: on)),
                ),
              ),
            if (hidden > 0)
              ActionChip(label: Text('+$hidden more'), onPressed: () => setState(() => _allCompanies = true)),
          ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Free cancellation only', style: textTheme.labelLarge),
          value: _draft.freeCancellation,
          onChanged: (on) => setState(() => _draft = _draft.copyWith(freeCancellation: on)),
        ),
        if (choices.searched > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: context.palette.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Filters cover all ${choices.searched} cars from this search, so changing them costs no new search.',
                  style: textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: valid ? () => widget.onApply(_draft) : null, child: const Text('Show cars')),
        ),
      ],
    );
  }
}
