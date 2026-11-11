import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A line of the sidebar or the drawer (Figma "v1/SidebarItem", 2302:40): 36 px, an optional icon and a label. Active,
/// it sits on `bgHover` with a brand icon and a bold label; hovered, it shows `bgHover` too. In the collapsed rail it
/// shows only its icon, with the label as a tooltip.
class SidebarItem extends StatelessWidget {
  const SidebarItem({
    required this.label,
    required this.onTap,
    this.icon,
    this.active = false,
    this.trailing,
    this.iconOnly = false,
    super.key,
  });

  final AppIcons? icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool iconOnly;

  static const height = 36.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final item = Material(
      color: active ? palette.bgHover : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        hoverColor: palette.bgHover,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: SizedBox(
          height: height,
          width: iconOnly ? 40 : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: iconOnly ? 0 : 10),
            child: Row(
              mainAxisAlignment: iconOnly ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                if (icon case final icon?) ...[
                  AppIcon(icon, size: 18, color: active ? palette.brandPrimary : palette.textPrimary),
                  if (!iconOnly) const SizedBox(width: 10),
                ],
                if (!iconOnly) ...[
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (active ? AppText.smallStrong : AppText.small).copyWith(
                        color: palette.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: iconOnly ? Tooltip(message: label, child: item) : item,
    );
  }
}

/// The small upper-case label above a group of items ("RECENTS").
class SidebarLabel extends StatelessWidget {
  const SidebarLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 18, 10, 6),
    child: Text(
      text.toUpperCase(),
      style: AppText.micro.copyWith(color: context.palette.textTertiary, letterSpacing: 0.5),
    ),
  );
}
