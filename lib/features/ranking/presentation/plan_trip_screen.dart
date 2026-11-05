import 'dart:async';

import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/page_frame.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/destination/presentation/widgets/common.dart';
import 'package:chocomousse/features/ranking/data/ranking_models.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/preferences_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// "Plan your trip" (S1). The preferences are a draft until "Find my best plans" saves them (plan decision 6).
class PlanTripScreen extends ConsumerStatefulWidget {
  const PlanTripScreen({required this.id, this.returnTo, super.key});

  final String id;

  /// The tab "Best for you" was on when Edit opened this screen; the button then goes back to it.
  final RankedKind? returnTo;

  @override
  ConsumerState<PlanTripScreen> createState() => _PlanTripScreenState();
}

class _PlanTripScreenState extends ConsumerState<PlanTripScreen> {
  late Preferences _draft = ref.read(tripSettingsProvider).preferences;
  bool _budgetValid = true;

  void _find() {
    ref.read(tripSettingsProvider.notifier).setPreferences(_draft);
    final returnTo = widget.returnTo;
    if (returnTo != null && context.canPop()) {
      context.pop();
    } else {
      unawaited(
        context.push('/discover/destination/${widget.id}/plan/best?tab=${(returnTo ?? RankedKind.hotels).name}'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final destination = ref.watch(destinationProvider(widget.id)).value;

    return PageFrame(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const BackCircleButton(),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Plan your trip', style: textTheme.headlineSmall),
                          if (destination != null)
                            Text('${destination.name}, ${destination.countryName}', style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                PreferencesForm(
                  value: _draft,
                  note:
                      'Culture, food, nature and nightlife count what is within walking distance of each hotel. '
                      'Flights and cars are ranked on budget and comfort.',
                  onChanged: (value, {required budgetValid}) => setState(() {
                    _draft = value;
                    _budgetValid = budgetValid;
                  }),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: _budgetValid ? _find : null, child: const Text('Find my best plans')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
