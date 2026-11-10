import 'dart:async';

import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/core/widgets/app_logo.dart';
import 'package:chocomousse/core/widgets/cards/plan_card_tile.dart';
import 'package:chocomousse/core/widgets/skeleton.dart';
import 'package:chocomousse/features/account/application/session.dart';
import 'package:chocomousse/features/chat/application/chat_controller.dart';
import 'package:chocomousse/features/chat/presentation/composer.dart';
import 'package:chocomousse/features/chat/presentation/trip_sheets.dart';
import 'package:chocomousse/features/chat/presentation/widgets/chat_layout.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:chocomousse/features/side_panel/presentation/side_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// What the home offers to ask (W1, M1).
const homeSuggestions = [
  'Plan 5 days in Rome',
  'Cheap flights from Beirut',
  'Hotels near the centre',
  'Rent a car in Lisbon',
  'Top sights in Paris',
  "What's on this weekend",
  'Visa & weather for Istanbul',
];

/// "Where to next, Sam?", or "Where to next?" without a name.
String homeGreeting(String? displayName) {
  final first = displayName?.trim().split(RegExp(r'\s+')).first ?? '';
  return first.isEmpty ? 'Where to next?' : 'Where to next, $first?';
}

/// The assistant's home (spec 008 US1, W1 and M1): the greeting, the composer, what to ask and the latest plans.
/// The first message starts a chat and moves to `/chat/{id}`.
class AssistantHome extends ConsumerStatefulWidget {
  const AssistantHome({this.openSaved = false, super.key});

  /// `/saved`: the home with its panel open on Saved.
  final bool openSaved;

  @override
  ConsumerState<AssistantHome> createState() => _AssistantHomeState();
}

class _AssistantHomeState extends ConsumerState<AssistantHome> {
  @override
  void initState() {
    super.initState();
    if (widget.openSaved) WidgetsBinding.instance.addPostFrameCallback((_) => _openSaved());
  }

  @override
  void didUpdateWidget(AssistantHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openSaved && !oldWidget.openSaved) _openSaved();
  }

  void _openSaved() {
    if (!mounted) return;
    ref.read(sidePanelProvider(homePanelKey).notifier).openPane(PanelPane.saved);
    if (MediaQuery.sizeOf(context).width < kWideLayoutBreakpoint) unawaited(showSidePanelSheet(context, homePanelKey));
  }

  void _send(String text) {
    final router = GoRouter.of(context);
    final chat = ref.read(chatProvider(null).notifier)
      ..onChatCreated = (id) => unawaited(router.replace<void>('/chat/$id'));
    unawaited(chat.send(text));
  }

  void _openPlan(String id) {
    ref.read(sidePanelProvider(homePanelKey).notifier).openPlan(id);
    if (MediaQuery.sizeOf(context).width < kWideLayoutBreakpoint) unawaited(showSidePanelSheet(context, homePanelKey));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final name = ref.watch(profileProvider.select((p) => p.value?.displayName));
    final sending = ref.watch(chatProvider(null).select((s) => s.isSending));

    final body = ListView(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, wide ? 96 : AppSpacing.xxl, AppSpacing.xl, AppSpacing.xxl),
      children: [
        ChatColumn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AppLogoMark(size: 44)),
              const SizedBox(height: AppSpacing.lg),
              Text(
                homeGreeting(name),
                textAlign: TextAlign.center,
                style: AppText.greeting.copyWith(color: palette.textPrimary),
              ),
              if (!wide) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  "Plan a trip, find flights, hotels and cars, or ask anything about where you're going.",
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: palette.textSecondary),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Composer(onSend: _send, sending: sending, autofocus: wide),
              const SizedBox(height: AppSpacing.lg),
              if (wide)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final text in homeSuggestions)
                      ActionChip(label: Text(text), onPressed: sending ? null : () => _send(text)),
                  ],
                )
              else
                SizedBox(
                  height: 88,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (_, i) => _SuggestionCard(
                      text: homeSuggestions[i],
                      onTap: sending ? null : () => _send(homeSuggestions[i]),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xxl),
              _LatestPlans(onOpen: _openPlan),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'TravelGenie checks prices with live sources. Prices can change before you book.',
                textAlign: TextAlign.center,
                style: AppText.small.copyWith(color: palette.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );

    return ChatLayout(
      chatKey: homePanelKey,
      child: Stack(
        children: [
          Positioned.fill(child: SafeArea(bottom: false, child: body)),
          if (wide)
            Positioned(
              top: AppSpacing.lg,
              right: AppSpacing.lg,
              child: OutlinedButton.icon(
                onPressed: () => unawaited(showPreferencesSheet(context)),
                icon: AppIcon(AppIcons.sliders, size: 16, color: palette.textPrimary),
                label: const Text('My preferences'),
              ),
            ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.text, required this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: 160,
      child: Material(
        color: palette.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: palette.borderDefault),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(text, style: AppText.smallStrong.copyWith(color: palette.textPrimary)),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Pick up where you left off": the two latest plans. Hidden when there are none.
class _LatestPlans extends ConsumerWidget {
  const _LatestPlans({required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final plans = ref.watch(plansProvider);
    final open = ref.watch(
      sidePanelProvider(homePanelKey).select((s) => s.open && s.pane == PanelPane.plan ? s.planId : null),
    );
    final header = Row(
      children: [
        Expanded(
          child: Text('Pick up where you left off', style: AppText.bodyStrong.copyWith(color: palette.textPrimary)),
        ),
        TextButton(onPressed: () => context.go('/plans'), child: const Text('All plans')),
      ],
    );
    return plans.when(
      skipLoadingOnRefresh: false,
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SkeletonBox(height: 80),
          const SizedBox(height: AppSpacing.sm),
          const SkeletonBox(height: 80),
        ],
      ),
      error: (e, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Row(
            children: [
              Expanded(
                child: Text(describeApiError(e), style: AppText.small.copyWith(color: palette.textSecondary)),
              ),
              TextButton(onPressed: () => ref.invalidate(plansProvider), child: const Text('Try again')),
            ],
          ),
        ],
      ),
      data: (list) {
        if (list.items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            for (final (i, plan) in list.items.take(2).indexed) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              PlanCardTile(plan: plan, selected: open == plan.id, onOpen: () => onOpen(plan.id)),
            ],
          ],
        );
      },
    );
  }
}
