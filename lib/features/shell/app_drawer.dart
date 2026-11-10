import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/shell/account_row.dart';
import 'package:chocomousse/features/shell/recents_list.dart';
import 'package:chocomousse/features/shell/search_chats_dialog.dart';
import 'package:chocomousse/features/shell/shell_nav.dart';
import 'package:flutter/material.dart';

/// The phone drawer (M5): a search field, the sidebar's places, Recents and the account. It closes after a choice.
class AppDrawer extends StatelessWidget {
  const AppDrawer({required this.location, super.key});

  final String location;

  static const width = 312.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    void close() => Navigator.of(context).pop();
    return Drawer(
      width: width,
      backgroundColor: palette.bgSidebar,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, AppSpacing.md, 12, AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                label: 'Search chats and plans',
                excludeSemantics: true,
                child: Material(
                  color: palette.bgSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    onTap: () {
                      close();
                      showSearchChats(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Row(
                        children: [
                          AppIcon(AppIcons.search, size: 18, color: palette.textSecondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Search chats and plans',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body.copyWith(color: palette.textTertiary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ShellNavItems(location: location, onChosen: close, skip: const {ShellPlace.search}),
              Expanded(
                child: RecentsList(location: location, onChosen: close),
              ),
              const AccountRow(),
            ],
          ),
        ),
      ),
    );
  }
}
