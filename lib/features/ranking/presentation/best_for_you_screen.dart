import 'dart:async';

import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/page_frame.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/destination/presentation/widgets/common.dart';
import 'package:chocomousse/features/ranking/data/ranking_models.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/preferences_form.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/ranked_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// "Best for you" (S2, S4–S6 on phones, W1 on wide screens): hotels, flights and cars ranked by the trip's
/// preferences, one tab at a time.
class BestForYouScreen extends ConsumerStatefulWidget {
  const BestForYouScreen({required this.id, required this.tab, super.key});

  final String id;
  final RankedKind tab;

  @override
  ConsumerState<BestForYouScreen> createState() => _BestForYouScreenState();
}

class _BestForYouScreenState extends ConsumerState<BestForYouScreen> {
  /// Wide screens save form changes once they settle (plan decision 11).
  static const settle = Duration(milliseconds: 500);

  Timer? _debounce;

  /// The form's value while a change settles, so a second slider move keeps the first.
  Preferences? _draft;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onFormChanged(Preferences value, {required bool budgetValid}) {
    _debounce?.cancel();
    setState(() => _draft = value);
    if (!budgetValid) return;
    _debounce = Timer(settle, () => ref.read(tripSettingsProvider.notifier).setPreferences(value));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final trip = ref.watch(tripSettingsProvider);
    final query = (
      destinationId: widget.id,
      from: trip.from,
      to: trip.to,
      adults: trip.adults,
      currency: trip.currency,
      driverAge: trip.driverAge,
      preferences: trip.preferences,
    );
    final base = '/discover/destination/${widget.id}/plan';

    final header = Row(
      children: [
        const BackCircleButton(),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Best for you', style: textTheme.headlineSmall),
              Text('Ranked by what matters to you', style: textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
    final tabs = Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final kind in RankedKind.values)
          ChoiceChip(
            label: Text(kind.label),
            selected: kind == widget.tab,
            onSelected: (_) => context.replace('$base/best?tab=${kind.name}'),
          ),
      ],
    );
    final body = RankedTab(kind: widget.tab, query: query, wide: wide);

    if (wide) {
      return PageFrame(
        children: [
          header,
          const SizedBox(height: AppSpacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 360,
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: PreferencesForm(
                  value: _draft ?? trip.preferences,
                  note: "The ranking updates as you move a slider; prices don't change and no new search runs.",
                  onChanged: _onFormChanged,
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    tabs,
                    const SizedBox(height: AppSpacing.lg),
                    body,
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    return PageFrame(
      children: [
        header,
        const SizedBox(height: AppSpacing.lg),
        tabs,
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(trip.preferences.summary, style: textTheme.bodySmall)),
            TextButton(onPressed: () => context.push('$base?edit=${widget.tab.name}'), child: const Text('Edit')),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        body,
      ],
    );
  }
}
