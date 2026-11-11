import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/core/widgets/app_logo.dart';
import 'package:chocomousse/features/shell/account_row.dart';
import 'package:chocomousse/features/shell/recents_list.dart';
import 'package:chocomousse/features/shell/shell_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the sidebar is collapsed to its rail. Kept for the app session.
class SidebarCollapsed extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final sidebarCollapsedProvider = NotifierProvider<SidebarCollapsed, bool>(SidebarCollapsed.new);

/// The wide-screen sidebar (W1): brand and collapse, the places, Recents and the account. Collapsed, a 64 px rail of
/// icons.
class Sidebar extends ConsumerWidget {
  const Sidebar({required this.location, this.forceRail = false, super.key});

  final String location;

  /// The side panel is open on a narrow desktop: the rail, whatever the traveller chose, until the panel closes.
  final bool forceRail;

  static const width = 272.0;
  static const railWidth = 64.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final collapsed = forceRail || ref.watch(sidebarCollapsedProvider);
    final toggle = IconButton(
      tooltip: forceRail
          ? 'Close the panel to open the sidebar'
          : collapsed
          ? 'Open sidebar'
          : 'Close sidebar',
      onPressed: forceRail ? null : ref.read(sidebarCollapsedProvider.notifier).toggle,
      icon: AppIcon(AppIcons.panelLeft, color: palette.textSecondary),
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: collapsed ? railWidth : width,
      color: palette.bgSidebar,
      // Laid out at its final width and clipped, so the content never squeezes while the width animates.
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: collapsed ? railWidth : width,
          maxWidth: collapsed ? railWidth : width,
          child: SafeArea(
            right: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: collapsed
                  ? Column(
                      children: [
                        toggle,
                        const SizedBox(height: 8),
                        ShellNavItems(location: location, iconOnly: true),
                        const Spacer(),
                        const AccountRow(iconOnly: true),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 44,
                          child: Row(
                            children: [
                              const SizedBox(width: 6),
                              const AppLogoMark(size: 28),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text('TravelGenie', style: AppText.title.copyWith(color: palette.textPrimary)),
                              ),
                              toggle,
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        ShellNavItems(location: location),
                        Expanded(child: RecentsList(location: location)),
                        const AccountRow(),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
