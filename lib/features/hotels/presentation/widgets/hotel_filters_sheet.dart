import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/hotels/data/hotel_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Opens the sort and filter sheet (H2) and returns the filters to apply, or null when it is dismissed.
Future<HotelFilters?> showHotelFiltersSheet(
  BuildContext context, {
  required HotelFilters filters,
  required int nights,
  required String currency,
}) {
  return showModalBottomSheet<HotelFilters>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
          child: HotelFiltersForm(
            filters: filters,
            nights: nights,
            currency: currency,
            showTitle: true,
            onApply: (applied) => Navigator.pop(context, applied),
          ),
        ),
      ),
    ),
  );
}

/// Sort and filters, edited as a copy and sent only on "Show hotels", so the list doesn't reload on every tap.
/// The phone sheet and the wide side panel (W1) both use it.
class HotelFiltersForm extends StatefulWidget {
  const HotelFiltersForm({
    required this.filters,
    required this.nights,
    required this.currency,
    required this.onApply,
    this.showTitle = false,
    super.key,
  });

  final HotelFilters filters;
  final int nights;
  final String currency;
  final ValueChanged<HotelFilters> onApply;
  final bool showTitle;

  @override
  State<HotelFiltersForm> createState() => _HotelFiltersFormState();
}

class _HotelFiltersFormState extends State<HotelFiltersForm> {
  late HotelFilters _draft = widget.filters;
  late final _min = TextEditingController(text: widget.filters.minPrice?.toString() ?? '');
  late final _max = TextEditingController(text: widget.filters.maxPrice?.toString() ?? '');

  @override
  void didUpdateWidget(HotelFiltersForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The side panel stays on screen while the list changes, so it follows the applied filters.
    if (oldWidget.filters != widget.filters) _reset(widget.filters);
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _reset(HotelFilters filters) => setState(() {
    _draft = filters;
    _min.text = filters.minPrice?.toString() ?? '';
    _max.text = filters.maxPrice?.toString() ?? '';
  });

  static int? _number(String text) => int.tryParse(text.trim());

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final valid = _draft.priceRangeIsValid;

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
          for (final sort in HotelSort.values)
            choice(
              sort.label,
              selected: _draft.sort == sort,
              onTap: () => setState(() => _draft = _draft.copyWith(sort: sort)),
            ),
        ]),
        group('Stars', [
          for (final stars in [null, 2, 3, 4, 5])
            choice(
              stars == null ? 'Any' : (stars == 5 ? '5' : '$stars+'),
              selected: _draft.minStars == stars,
              onTap: () => setState(() => _draft = _draft.copyWith(minStars: () => stars)),
            ),
        ]),
        group('Review score', [
          for (final review in [null, 7, 8, 9])
            choice(
              review == null ? 'Any' : '$review+',
              selected: _draft.minReview == review,
              onTap: () => setState(() => _draft = _draft.copyWith(minReview: () => review)),
            ),
        ]),
        Text(
          'Total price for ${widget.nights == 1 ? '1 night' : '${widget.nights} nights'} (${widget.currency})',
          style: textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _PriceField(
                label: 'Min',
                controller: _min,
                onChanged: (v) => setState(() => _draft = _draft.copyWith(minPrice: () => _number(v))),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _PriceField(
                label: 'Max',
                controller: _max,
                onChanged: (v) => setState(() => _draft = _draft.copyWith(maxPrice: () => _number(v))),
              ),
            ),
          ],
        ),
        if (!valid) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'The minimum price is above the maximum.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.danger),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        group('Type of stay', [
          for (final type in hotelStayTypes)
            FilterChip(
              label: Text(type),
              selected: _draft.stayTypes.contains(type),
              onSelected: (on) => setState(
                () => _draft = _draft.copyWith(
                  stayTypes: on ? [..._draft.stayTypes, type] : _draft.stayTypes.where((t) => t != type).toList(),
                ),
              ),
            ),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Free cancellation only', style: textTheme.labelLarge),
          value: _draft.freeCancellation,
          onChanged: (on) => setState(() => _draft = _draft.copyWith(freeCancellation: on)),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: valid ? () => widget.onApply(_draft) : null, child: const Text('Show hotels')),
        ),
      ],
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({required this.label, required this.controller, required this.onChanged});

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, hintText: 'Any'),
      onChanged: onChanged,
    );
  }
}
