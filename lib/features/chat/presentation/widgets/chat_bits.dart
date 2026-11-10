import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/cards/media_card.dart';
import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/chat/presentation/widgets/card_views.dart';
import 'package:flutter/material.dart';

/// The traveller's message (Figma 2302:51), on the right.
class UserBubble extends StatelessWidget {
  const UserBubble(this.message, {super.key});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
          decoration: BoxDecoration(color: palette.bgSubtle, borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Text(message.text, style: AppText.body.copyWith(color: palette.textPrimary)),
        ),
      ),
    );
  }
}

/// The icon of a tool the assistant ran, by the contract's tool names; sparkles for any other.
AppIcons toolIcon(String tool) => switch (tool) {
  'find_city' => AppIcons.search,
  'get_overview' => AppIcons.globe,
  'list_places' || 'suggest_day_alternatives' => AppIcons.landmark,
  'list_events' => AppIcons.ticket,
  'search_flights' => AppIcons.plane,
  'search_hotels' => AppIcons.bed,
  'search_cars' => AppIcons.car,
  'build_plan' || 'rebuild_plan' || 'list_plans' || 'get_plan' || 'update_plan' => AppIcons.calendar,
  'list_plan_alternatives' || 'swap_plan_offer' || 'remove_plan_car' || 'change_day_item' => AppIcons.swap,
  'get_preferences' || 'update_preferences' => AppIcons.sliders,
  'save_item' || 'list_saved' => AppIcons.bookmark,
  _ => AppIcons.sparkles,
};

/// One tool step (Figma 2302:41): its icon and summary, and a chevron that shows its cards. A failed step is in the
/// warning colour.
class ToolStepLine extends StatefulWidget {
  const ToolStepLine({required this.step, required this.chatKey, super.key});

  final ToolStep step;
  final String chatKey;

  @override
  State<ToolStepLine> createState() => _ToolStepLineState();
}

class _ToolStepLineState extends State<ToolStepLine> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final step = widget.step;
    final color = step.ok ? palette.textSecondary : palette.statusWarning;
    final expandable = step.cards.isNotEmpty;
    final line = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          AppIcon(toolIcon(step.tool), size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(step.summary, style: AppText.small.copyWith(color: color)),
          ),
          if (expandable) ...[
            const SizedBox(width: AppSpacing.xs),
            AnimatedRotation(
              turns: _open ? 0.25 : 0,
              duration: const Duration(milliseconds: 150),
              child: AppIcon(AppIcons.chevronRight, size: 14, color: color),
            ),
          ],
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: expandable,
          expanded: expandable ? _open : null,
          child: expandable
              ? InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  onTap: () => setState(() => _open = !_open),
                  child: line,
                )
              : line,
        ),
        if (_open) ...[
          const SizedBox(height: AppSpacing.sm),
          CardGroup(cards: step.cards, chatKey: widget.chatKey, total: step.total),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// Shown under the last step while the answer is being written.
class WorkingIndicator extends StatelessWidget {
  const WorkingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      liveRegion: true,
      label: 'Working on it',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: palette.brandPrimary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Working on it…', style: AppText.small.copyWith(color: palette.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// Cards of one kind under a Micro label: at most 6, hotels in a row that scrolls sideways, the others stacked, and
/// "See all {total}" when there are more.
class CardGroup extends StatelessWidget {
  const CardGroup({required this.cards, required this.chatKey, this.total, this.onSeeAll, super.key});

  static const maxShown = 6;

  final List<AssistantCard> cards;
  final String chatKey;

  /// How many the tool found.
  final int? total;

  /// Opens the whole list (spec 008 US2); the button is off until then.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    final palette = context.palette;
    final shown = cards.take(maxShown).toList();
    final total = this.total;
    final media = shown.first is HotelCard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(CardKind.of(shown.first).label, style: AppText.micro.copyWith(color: palette.textSecondary)),
            ),
            if (total != null && total > shown.length) TextButton(onPressed: onSeeAll, child: Text('See all $total')),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (media)
          SizedBox(
            height: MediaCard.height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: shown.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (_, i) => AssistantCardView(card: shown[i], chatKey: chatKey),
            ),
          )
        else
          for (final (i, card) in shown.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            AssistantCardView(card: card, chatKey: chatKey),
          ],
      ],
    );
  }
}

/// What to ask next (Figma 2302:20). Each chip sends its text.
class SuggestionChips extends StatelessWidget {
  const SuggestionChips({required this.suggestions, required this.onSend, super.key});

  final List<String> suggestions;
  final ValueChanged<String>? onSend;

  @override
  Widget build(BuildContext context) {
    final onSend = this.onSend;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final text in suggestions)
          ActionChip(label: Text(text), onPressed: onSend == null ? null : () => onSend(text)),
      ],
    );
  }
}

/// An assistant message: its steps, its text, then its cards grouped by kind (plan, flights, hotels, cars, places,
/// events, facts).
class AnswerView extends StatelessWidget {
  const AnswerView({required this.message, required this.chatKey, super.key});

  final ChatMessage message;
  final String chatKey;

  /// The total a step found for cards of [kind], for "See all".
  int? _totalOf(CardKind kind) =>
      message.steps.where((s) => s.cards.any((c) => CardKind.of(c) == kind)).map((s) => s.total).nonNulls.firstOrNull;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final step in message.steps) ToolStepLine(step: step, chatKey: chatKey),
        if (message.steps.isNotEmpty) const SizedBox(height: AppSpacing.sm),
        if (message.text.isNotEmpty)
          SelectableText(message.text, style: AppText.body.copyWith(color: palette.textPrimary)),
        for (final warning in message.warnings) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(warning, style: AppText.small.copyWith(color: palette.statusWarning)),
        ],
        for (final kind in CardKind.values)
          if (message.cards.where((c) => CardKind.of(c) == kind).toList() case final cards when cards.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            CardGroup(cards: cards, chatKey: chatKey, total: _totalOf(kind)),
          ],
      ],
    );
  }
}
