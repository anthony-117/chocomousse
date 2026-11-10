import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/account/application/session.dart';
import 'package:chocomousse/features/shell/account_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The traveller at the bottom of the sidebar and the drawer: initial, name and pace. It opens the account menu.
class AccountRow extends ConsumerWidget {
  const AccountRow({this.iconOnly = false, super.key});

  /// In the collapsed rail: the initial only.
  final bool iconOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final profile = ref.watch(profileProvider).value;
    final name = profile?.displayName ?? 'Your account';
    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: palette.brandAccentSoft,
      child: Text(profile?.initial ?? '?', style: AppText.smallStrong.copyWith(color: palette.brandAccent)),
    );
    return AccountMenu(
      builder: (context, open) => Semantics(
        button: true,
        label: 'Account: $name',
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: open,
            hoverColor: palette.bgHover,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
              child: iconOnly
                  ? avatar
                  : Row(
                      children: [
                        avatar,
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.smallStrong.copyWith(color: palette.textPrimary, fontSize: 14),
                              ),
                              if (profile != null)
                                Text(
                                  '${profile.pace.label} pace',
                                  style: AppText.small.copyWith(color: palette.textSecondary),
                                ),
                            ],
                          ),
                        ),
                        AppIcon(AppIcons.chevronDown, size: 16, color: palette.textSecondary),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
