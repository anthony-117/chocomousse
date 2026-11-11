import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/core/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Indigo → coral gradient used for destination photos until real photos are wired in.
LinearGradient photoGradient(BuildContext context) => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [context.palette.brandPrimary, context.palette.brandAccent],
);

/// Marks a details view shown inside the side panel (spec 008 US2): its back buttons hide, since the panel has
/// its own tabs and Close.
class EmbeddedDetails extends InheritedWidget {
  const EmbeddedDetails({required super.child, super.key});

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<EmbeddedDetails>() != null;

  @override
  bool updateShouldNotify(EmbeddedDetails oldWidget) => false;
}

/// Soft round back button from the v0.2 design. Hidden inside [EmbeddedDetails].
class BackCircleButton extends StatelessWidget {
  const BackCircleButton({this.onDark = false, super.key});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    if (EmbeddedDetails.of(context)) return const SizedBox.shrink();
    return Material(
      color: onDark ? Colors.white.withValues(alpha: 0.9) : context.palette.bgApp,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: 'Back',
        icon: Icon(Icons.chevron_left, color: context.palette.textPrimary),
        onPressed: () => context.canPop() ? context.pop() : context.go('/discover'),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.action, this.onAction, super.key});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(title, style: textTheme.titleMedium)),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(action!, style: textTheme.labelSmall?.copyWith(color: context.palette.brandPrimary)),
          ),
      ],
    );
  }
}

/// One fact on the overview (InfoTile in Figma): title, big value, small note.
class FactTile extends StatelessWidget {
  const FactTile({required this.icon, required this.title, required String this.value, this.note, this.tone, super.key})
    : animate = false;

  /// The same tile with empty boxes in place of its value and note.
  const FactTile.placeholder({required this.icon, required this.title, this.animate = true, super.key})
    : value = null,
      note = null,
      tone = null;

  final IconData icon;
  final String title;
  final String? value;
  final String? note;

  /// Optional colour for the value (e.g. green for visa free, red for level 4).
  final Color? tone;

  /// Whether a placeholder's boxes pulse.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.palette.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.palette.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: context.palette.textSecondary),
              const SizedBox(width: 6),
              Flexible(child: Text(title, style: textTheme.bodySmall)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (value case final value?)
            Text(
              value,
              style: textTheme.titleMedium?.copyWith(color: tone),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          else ...[
            SkeletonBox(width: 80, height: 20, animate: animate),
            const SizedBox(height: AppSpacing.xs),
            SkeletonBox(width: 110, height: 12, animate: animate),
          ],
          if (note != null) Text(note!, style: textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Quiet note for a section that has no data (missing API key, source down).
class WarningNote extends StatelessWidget {
  const WarningNote(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(color: context.palette.bgApp, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: context.palette.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// Error banner with retry, shown above a screen's or section's placeholders.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({required this.error, required this.onRetry, super.key});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      decoration: BoxDecoration(color: context.palette.bgApp, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: context.palette.textSecondary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(describeApiError(error), style: Theme.of(context).textTheme.bodySmall)),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
