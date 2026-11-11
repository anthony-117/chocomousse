import 'package:chocomousse/app/router.dart';
import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/features/chat/application/chat_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The phone top bar (M1, M2): menu, the place's title, and New trip chat.
class MobileTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const MobileTopBar({required this.location, required this.onMenu, super.key});

  final String location;
  final VoidCallback onMenu;

  /// The places that show this bar. Deeper screens (a city, a list, a details screen) keep their own back header.
  static bool showsOn(String location) =>
      const {AppPaths.home, AppPaths.saved, AppPaths.explore, AppPaths.plans, AppPaths.profile}.contains(location) ||
      _chatId(location) != null;

  static String? _chatId(String location) {
    final segments = Uri.parse(location).pathSegments;
    return segments.length == 2 && segments.first == 'chat' ? segments.last : null;
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final chatId = _chatId(location);
    final title = chatId == null
        ? switch (location) {
            AppPaths.saved => 'Saved',
            AppPaths.explore => 'Explore',
            AppPaths.plans => 'My plans',
            AppPaths.profile => 'Profile',
            _ => 'TravelGenie',
          }
        : ref.watch(chatProvider(chatId).select((s) => s.title)) ?? 'New chat';
    return Material(
      color: palette.bgApp,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Open menu',
                onPressed: onMenu,
                icon: AppIcon(AppIcons.menu, color: palette.textPrimary),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: (chatId == null ? AppText.title : AppText.bodyStrong).copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    if (chatId != null) ...[
                      const SizedBox(width: 4),
                      AppIcon(AppIcons.chevronDown, size: 16, color: palette.textSecondary),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'New trip chat',
                onPressed: () => GoRouter.of(context).go(AppPaths.home),
                icon: AppIcon(AppIcons.newChat, color: palette.textPrimary),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
