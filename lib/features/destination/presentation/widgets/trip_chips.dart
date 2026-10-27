import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// "Travelling with" chips (design 03): passport, currency and dates, each editable.
class TripChips extends ConsumerWidget {
  const TripChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripSettingsProvider);
    final notifier = ref.read(tripSettingsProvider.notifier);
    final dates = '${DateFormat('d MMM').format(trip.from)} – ${DateFormat('d MMM').format(trip.to)}';

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        ActionChip(
          avatar: const Icon(Icons.badge_outlined, size: 16, color: AppColors.primary),
          label: Text('Passport: ${trip.passport}'),
          onPressed: () async {
            final code = await _pickCountry(context, title: 'Your passport', value: (c) => c.code);
            if (code != null) notifier.setPassport(code);
          },
        ),
        ActionChip(
          avatar: const Icon(Icons.payments_outlined, size: 16, color: AppColors.primary),
          label: Text(trip.currency),
          onPressed: () async {
            final code = await _pickCountry(
              context,
              title: 'Your currency',
              value: (c) => c.currencies.isEmpty ? null : c.currencies.first,
            );
            if (code != null) notifier.setCurrency(code);
          },
        ),
        ActionChip(
          avatar: const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primary),
          label: Text(dates),
          onPressed: () async {
            final now = DateTime.now();
            final range = await showDateRangePicker(
              context: context,
              firstDate: DateTime(now.year, now.month, now.day),
              lastDate: now.add(const Duration(days: 365 * 2)),
              initialDateRange: DateTimeRange(start: trip.from, end: trip.to),
            );
            if (range == null) return;
            // The API accepts trips of up to 30 days.
            final end = range.end.difference(range.start).inDays > 30
                ? range.start.add(const Duration(days: 30))
                : range.end;
            notifier.setDates(range.start, end);
          },
        ),
      ],
    );
  }

  /// Bottom sheet listing countries; returns [value] of the picked one.
  Future<String?> _pickCountry(
    BuildContext context, {
    required String title,
    required String? Function(CountryOption) value,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _CountryPicker(title: title, value: value),
    );
  }
}

class _CountryPicker extends ConsumerStatefulWidget {
  const _CountryPicker({required this.title, required this.value});

  final String title;
  final String? Function(CountryOption) value;

  @override
  ConsumerState<_CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends ConsumerState<_CountryPicker> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final countries = ref.watch(countriesProvider);
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Search a country', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: countries.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Could not load countries.', style: textTheme.bodyLarge)),
                data: (all) {
                  final items = all
                      .where((c) => widget.value(c) != null)
                      .where(
                        (c) =>
                            _filter.isEmpty ||
                            c.name.toLowerCase().contains(_filter) ||
                            c.code.toLowerCase() == _filter,
                      )
                      .toList();
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final c = items[i];
                      return ListTile(
                        leading: Text(c.flag ?? '', style: const TextStyle(fontSize: 22)),
                        title: Text(c.name),
                        trailing: Text(widget.value(c)!, style: textTheme.labelSmall),
                        onTap: () => Navigator.pop(context, widget.value(c)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
