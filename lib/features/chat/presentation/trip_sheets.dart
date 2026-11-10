import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/chat/application/chat_trip.dart';
import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/itinerary/presentation/widgets/plan_texts.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/pace_choice.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/preferences_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The longest trip the API plans, in nights.
const _maxTripDays = 30;

Future<void> _sheet(BuildContext context, Widget child) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: child,
  ),
);

/// The composer's trip chip: the city, the dates and the adults (spec 008 US1).
Future<void> showTripEditor(BuildContext context) => _sheet(context, const TripEditorSheet());

/// The composer's preferences chip, and My preferences on the home: the six sliders and the pace.
Future<void> showPreferencesSheet(BuildContext context) => _sheet(context, const PreferencesSheet());

/// The trip a message is about. Done writes it to the chips.
class TripEditorSheet extends ConsumerStatefulWidget {
  const TripEditorSheet({super.key});

  @override
  ConsumerState<TripEditorSheet> createState() => _TripEditorSheetState();
}

class _TripEditorSheetState extends ConsumerState<TripEditorSheet> {
  late ChatTrip _trip = ref.read(chatTripProvider).trip;
  final _city = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final from = _trip.from;
    final to = _trip.to;
    final range = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 2)),
      initialDateRange: from != null && to != null && !from.isBefore(today)
          ? DateTimeRange(start: from, end: to)
          : null,
    );
    if (range == null || !mounted) return;
    final end = range.end.difference(range.start).inDays > _maxTripDays
        ? range.start.add(const Duration(days: _maxTripDays))
        : range.end;
    setState(() => _trip = _copy(from: range.start, to: end));
  }

  ChatTrip _copy({String? destinationId, String? destinationName, DateTime? from, DateTime? to, int? adults}) =>
      ChatTrip(
        destinationId: destinationId ?? _trip.destinationId,
        destinationName: destinationName ?? _trip.destinationName,
        from: from ?? _trip.from,
        to: to ?? _trip.to,
        adults: adults ?? _trip.adults,
        originId: _trip.originId,
        originName: _trip.originName,
        passport: _trip.passport,
        currency: _trip.currency,
        tripBudget: _trip.tripBudget,
      );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final from = _trip.from;
    final to = _trip.to;
    final adults = _trip.adults ?? 2;
    final results = _query.trim().length < 2 ? null : ref.watch(destinationSearchProvider(_query));

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your trip', style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          Text('Where', style: AppText.smallStrong.copyWith(color: palette.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          if (_trip.destinationName case final name? when _query.isEmpty)
            InputChip(
              label: Text(name),
              onDeleted: () => setState(
                () => _trip = ChatTrip(
                  from: _trip.from,
                  to: _trip.to,
                  adults: _trip.adults,
                  originId: _trip.originId,
                  originName: _trip.originName,
                  passport: _trip.passport,
                  currency: _trip.currency,
                  tripBudget: _trip.tripBudget,
                ),
              ),
            ),
          TextField(
            controller: _city,
            decoration: const InputDecoration(hintText: 'Search a city'),
            onChanged: (text) => setState(() => _query = text),
          ),
          if (results != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: results.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => const ListTile(title: Text("Couldn't search cities. Try again.")),
                data: (cities) => cities.isEmpty
                    ? const ListTile(title: Text('No city found'))
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final city in cities)
                            ListTile(
                              title: Text(city.name),
                              subtitle: Text(city.countryName),
                              onTap: () => setState(() {
                                _trip = _copy(destinationId: city.id, destinationName: city.name);
                                _city.clear();
                                _query = '';
                              }),
                            ),
                        ],
                      ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: _pickDates,
            child: Text(from == null || to == null ? 'Choose dates' : planDates(from, to)),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: Text('Adults', style: textTheme.bodyLarge)),
              IconButton.outlined(
                tooltip: 'Fewer adults',
                onPressed: adults > 1 ? () => setState(() => _trip = _copy(adults: adults - 1)) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 40,
                child: Text('$adults', textAlign: TextAlign.center, style: textTheme.titleMedium),
              ),
              IconButton.outlined(
                tooltip: 'More adults',
                onPressed: adults < TripSettings.maxAdults
                    ? () => setState(() => _trip = _copy(adults: adults + 1))
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () {
              ref.read(chatTripProvider.notifier).setTrip(_trip);
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

/// The level nearest to a weight from the profile or a chat.
Level _levelOf(int? weight) {
  if (weight == null) return Level.medium;
  return Level.values.reduce((a, b) => (a.weight - weight).abs() <= (b.weight - weight).abs() ? a : b);
}

/// The six preferences and the pace the next messages use. Done writes them to the chips; the profile stays as it is.
class PreferencesSheet extends ConsumerStatefulWidget {
  const PreferencesSheet({super.key});

  @override
  ConsumerState<PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends ConsumerState<PreferencesSheet> {
  late final Map<Criterion, Level> _levels = {
    for (final c in Criterion.values) c: _levelOf(ref.read(chatTripProvider).preferences[c.name]),
  };
  late Pace _pace = ref.read(chatTripProvider).pace;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('My preferences', style: textTheme.titleLarge),
          Text('Used for the next messages of this chat.', style: textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          for (final c in Criterion.values)
            LevelSlider(criterion: c, level: _levels[c]!, onChanged: (level) => setState(() => _levels[c] = level)),
          const SizedBox(height: AppSpacing.lg),
          PaceChoice(value: _pace, onChanged: (pace) => setState(() => _pace = pace)),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () {
              ref.read(chatTripProvider.notifier)
                ..setPreferences({for (final e in _levels.entries) e.key.name: e.value.weight})
                ..setPace(_pace);
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
