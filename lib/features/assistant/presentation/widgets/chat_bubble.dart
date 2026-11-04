import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/assistant/data/assistant_models.dart';
import 'package:flutter/material.dart';

/// One message (ChatBubble in Figma 09/W6): the traveller's on the right in indigo, the assistant's on the left in white.
class ChatBubble extends StatelessWidget {
  const ChatBubble({required this.role, required this.child, super.key});

  /// The assistant's bubble with text.
  factory ChatBubble.text(ChatMessage message, {Key? key}) => ChatBubble(
    key: key,
    role: message.role,
    child: _BubbleText(message.text, role: message.role),
  );

  final ChatRole role;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final traveller = role == ChatRole.traveller;
    final maxWidth = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint ? 560.0 : 290.0;
    const corner = Radius.circular(AppRadius.lg);

    return Align(
      alignment: traveller ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: traveller ? AppColors.primary : AppColors.surface,
            border: traveller ? null : Border.all(color: AppColors.border),
            borderRadius: BorderRadius.only(
              topLeft: corner,
              topRight: corner,
              bottomLeft: traveller ? corner : const Radius.circular(AppRadius.sm),
              bottomRight: traveller ? const Radius.circular(AppRadius.sm) : corner,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _BubbleText extends StatelessWidget {
  const _BubbleText(this.text, {required this.role});

  final String text;
  final ChatRole role;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: role == ChatRole.traveller ? AppColors.onPrimary : AppColors.text, height: 1.4);
    return SelectableText(text, style: style);
  }
}

/// Shown on the assistant's side while an answer is on its way. Static, so it never keeps a test waiting.
class TypingBubble extends StatelessWidget {
  const TypingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return ChatBubble(
      role: ChatRole.assistant,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[if (i > 0) const SizedBox(width: AppSpacing.xs), const _Dot()],
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: Text('Checking TravelGenie…', style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 6,
    child: DecoratedBox(
      decoration: BoxDecoration(color: AppColors.muted, shape: BoxShape.circle),
    ),
  );
}

/// An answer that is only a warning (assistant busy or not configured), with Try again.
class WarningBubble extends StatelessWidget {
  const WarningBubble({required this.warnings, required this.onRetry, super.key});

  final List<String> warnings;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ChatBubble(
      role: ChatRole.assistant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final warning in warnings) Text(warning, style: Theme.of(context).textTheme.bodyMedium),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

/// Small note under an answer, naming a source that had no data.
class ReplyWarnings extends StatelessWidget {
  const ReplyWarnings(this.warnings, {super.key});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted);
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final warning in warnings)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 14, color: AppColors.muted),
                const SizedBox(width: AppSpacing.xs),
                Flexible(child: Text(warning, style: style)),
              ],
            ),
        ],
      ),
    );
  }
}

/// Under a traveller message whose request failed.
class NotSentNote extends StatelessWidget {
  const NotSentNote({required this.error, required this.onRetry, super.key});

  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger);
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.end,
        children: [
          Text(error == null ? 'Not sent.' : 'Not sent. $error', style: style),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
