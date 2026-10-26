import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../app/theme/tokens.dart';

/// Minimal floating tab bar from the approved v0.2 design: light pill, icons only,
/// active tab drawn as an indigo circle.
class FloatingNav extends StatelessWidget {
  const FloatingNav({required this.current, required this.onSelect, super.key});

  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  static const height = 64.0;

  static const _icons = {
    AppTab.discover: Icons.explore_outlined,
    AppTab.plans: Icons.work_outline,
    AppTab.assistant: Icons.auto_awesome_outlined,
    AppTab.profile: Icons.person_outline,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.border),
        boxShadow: kSoftShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final tab in AppTab.values)
            _NavButton(icon: _icons[tab]!, label: tab.label, selected: tab == current, onTap: () => onSelect(tab)),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // No visible text by design, so the label is exposed to screen readers and as a tooltip.
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: selected ? AppColors.primary : Colors.transparent, shape: BoxShape.circle),
            child: Icon(icon, size: 24, color: selected ? AppColors.onPrimary : AppColors.muted),
          ),
        ),
      ),
    );
  }
}
