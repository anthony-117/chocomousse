import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/network/api_client.dart';

/// Indigo → coral gradient used for destination photos until real photos are wired in.
const LinearGradient kPhotoGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppColors.primary, AppColors.accent],
);

/// Soft round back button from the v0.2 design.
class BackCircleButton extends StatelessWidget {
  const BackCircleButton({this.onDark = false, super.key});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onDark ? Colors.white.withValues(alpha: 0.9) : AppColors.canvas,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.chevron_left, color: AppColors.text),
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
            child: Text(action!, style: textTheme.labelSmall?.copyWith(color: AppColors.primary)),
          ),
      ],
    );
  }
}

/// One fact on the overview (InfoTile in Figma): title, big value, small note.
class FactTile extends StatelessWidget {
  const FactTile({required this.icon, required this.title, required this.value, this.note, this.tone, super.key});

  final IconData icon;
  final String title;
  final String value;
  final String? note;

  /// Optional colour for the value (e.g. green for visa free, red for level 4).
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Flexible(child: Text(title, style: textTheme.bodySmall)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(color: tone),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
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
      decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.muted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// Error block with retry, for a whole screen or section.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({required this.error, required this.onRetry, super.key});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.muted, size: 32),
          const SizedBox(height: AppSpacing.sm),
          Text(describeApiError(error), style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class LoadingBlock extends StatelessWidget {
  const LoadingBlock({this.height = 120, super.key});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
  );
}
