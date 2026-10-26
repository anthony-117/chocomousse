import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../app/theme/tokens.dart';
import '../../core/widgets/app_logo.dart';

/// Desktop header from the approved web design (W1–W9): logo, main links, avatar for Profile.
class WebHeader extends StatelessWidget {
  const WebHeader({required this.current, required this.onSelect, super.key});

  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 18),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const AppWordmark(),
          const SizedBox(width: 40),
          for (final tab in [AppTab.discover, AppTab.plans, AppTab.assistant])
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: _HeaderLink(
                label: tab.label,
                selected: tab == current,
                onTap: () => onSelect(tab),
                style: textTheme.labelLarge,
              ),
            ),
          const Spacer(),
          Tooltip(
            message: AppTab.profile.label,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onSelect(AppTab.profile),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: current == AppTab.profile ? AppColors.primary : AppColors.primarySoft,
                child: Icon(
                  Icons.person_outline,
                  color: current == AppTab.profile ? AppColors.onPrimary : AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderLink extends StatelessWidget {
  const _HeaderLink({required this.label, required this.selected, required this.onTap, this.style});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.full),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(label, style: style?.copyWith(color: selected ? AppColors.primary : AppColors.muted)),
      ),
    );
  }
}
