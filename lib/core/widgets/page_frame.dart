import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../features/shell/floating_nav.dart';

/// Standard scrollable page: mobile padding and room for the floating nav on phones,
/// wider centred content on the web layout.
class PageFrame extends StatelessWidget {
  const PageFrame({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final padding = wide
        ? const EdgeInsets.fromLTRB(64, 40, 64, 64)
        : const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, FloatingNav.height + 48);

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: padding,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1312),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ),
      ),
    );
  }
}

/// Soft grey card used for empty states and information blocks (minimalist v0.2 style).
class SoftCard extends StatelessWidget {
  const SoftCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: child,
    );
  }
}

/// Icon, title and short message shown where a feature arrives in a later sprint.
class EmptyState extends StatelessWidget {
  const EmptyState({required this.icon, required this.title, required this.message, super.key});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SoftCard(
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primarySoft,
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(message, style: textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
