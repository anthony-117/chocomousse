import 'package:chocomousse/app/router.dart';
import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/features/shell/search_chats_dialog.dart';
import 'package:chocomousse/features/shell/widgets/sidebar_item.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The shell's places, in the sidebar's order.
enum ShellPlace {
  newChat(AppIcons.newChat, 'New trip chat', AppPaths.home),
  search(AppIcons.search, 'Search chats', null),
  explore(AppIcons.compass, 'Explore', AppPaths.explore),
  plans(AppIcons.map, 'My plans', AppPaths.plans),
  saved(AppIcons.bookmark, 'Saved', AppPaths.saved);

  ShellPlace(this.icon, this.label, this.path);

  final AppIcons icon;
  final String label;

  /// Where it goes; null for Search chats, which opens a dialog.
  final String? path;

  /// The place [location] belongs to, or null (a chat, the profile).
  static ShellPlace? of(String location) {
    if (location == AppPaths.home) return newChat;
    if (location == AppPaths.saved) return saved;
    if (location == AppPaths.explore || location.startsWith('${AppPaths.explore}/')) return explore;
    if (location == AppPaths.plans || location.startsWith('${AppPaths.plans}/')) return plans;
    return null;
  }
}

/// The sidebar's and the drawer's items. [onChosen] runs after a choice (the drawer closes).
class ShellNavItems extends StatelessWidget {
  const ShellNavItems({required this.location, this.iconOnly = false, this.onChosen, this.skip = const {}, super.key});

  final String location;
  final bool iconOnly;
  final VoidCallback? onChosen;

  /// Places this list leaves out (the drawer has its own search field).
  final Set<ShellPlace> skip;

  @override
  Widget build(BuildContext context) {
    final active = ShellPlace.of(location);
    return Column(
      crossAxisAlignment: iconOnly ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
      children: [
        for (final place in ShellPlace.values)
          if (!skip.contains(place))
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: SidebarItem(
                icon: place.icon,
                label: place.label,
                active: place == active,
                iconOnly: iconOnly,
                onTap: () {
                  onChosen?.call();
                  final path = place.path;
                  if (path == null) {
                    showSearchChats(context);
                  } else {
                    GoRouter.of(context).go(path);
                  }
                },
              ),
            ),
      ],
    );
  }
}
