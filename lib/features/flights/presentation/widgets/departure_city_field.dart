import 'dart:async';

import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/data/models.dart';
import 'package:chocomousse/features/destination/presentation/widgets/common.dart';
import 'package:chocomousse/features/flights/application/flight_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Flying from": shows the chosen city and opens the picker.
class DepartureCityField extends ConsumerWidget {
  const DepartureCityField({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final city = ref.watch(departureCityProvider);

    return Material(
      color: context.palette.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: city == null ? context.palette.brandPrimary : context.palette.borderDefault),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () async {
          final chosen = await pickCity(context, title: 'Where are you flying from?');
          if (chosen != null) ref.read(departureCityProvider.notifier).choose(chosen);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.place_outlined, color: context.palette.brandPrimary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Flying from', style: textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      city?.name ?? 'Choose a city',
                      style: textTheme.labelLarge?.copyWith(color: city == null ? context.palette.textSecondary : null),
                    ),
                  ],
                ),
              ),
              Icon(Icons.expand_more, color: context.palette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// A city search in a sheet; returns the city picked, or null.
Future<DestinationSummary?> pickCity(BuildContext context, {required String title}) =>
    showModalBottomSheet<DestinationSummary>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _DepartureCityPicker(title: title),
    );

class _DepartureCityPicker extends ConsumerStatefulWidget {
  const _DepartureCityPicker({required this.title});

  final String title;

  @override
  ConsumerState<_DepartureCityPicker> createState() => _DepartureCityPickerState();
}

class _DepartureCityPickerState extends ConsumerState<_DepartureCityPicker> {
  static const _debounce = Duration(milliseconds: 300);

  Timer? _timer;
  String _query = '';

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(_debounce, () => setState(() => _query = value.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final results = ref.watch(destinationSearchProvider(_query));

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
              onChanged: _onChanged,
              decoration: const InputDecoration(hintText: 'Search a city', prefixIcon: Icon(Icons.search)),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: results.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Align(
                  alignment: Alignment.topCenter,
                  child: ErrorRetry(error: e, onRetry: () => ref.invalidate(destinationSearchProvider(_query))),
                ),
                data: (items) => items.isEmpty && _query.length >= 2
                    ? Text('No city matches "$_query".', style: textTheme.bodyLarge)
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final city = items[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.place_outlined, color: context.palette.brandPrimary),
                            title: Text(city.name, style: textTheme.labelLarge),
                            subtitle: Text('${city.subtitle} ${city.flag ?? ''}'.trim(), style: textTheme.bodySmall),
                            onTap: () => Navigator.pop(context, city),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
