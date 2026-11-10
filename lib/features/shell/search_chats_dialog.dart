import 'dart:async';

import 'package:chocomousse/app/router.dart';
import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/cards/plan_card_tile.dart';
import 'package:chocomousse/features/chat/application/recents.dart';
import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/shell/recents_list.dart';
import 'package:chocomousse/features/shell/widgets/sidebar_item.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:chocomousse/features/side_panel/presentation/side_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Opens Search chats (spec 008 US5): a dialog on wide screens, a full-screen sheet on phones.
void showSearchChats(BuildContext context) {
  final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
  unawaited(
    showDialog<void>(
      context: context,
      builder: (_) => wide
          ? Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
                child: const SearchChatsView(),
              ),
            )
          : const Dialog.fullscreen(child: SafeArea(child: SearchChatsView())),
    ),
  );
}

/// The search field and its two groups, Chats and Plans.
class SearchChatsView extends ConsumerStatefulWidget {
  const SearchChatsView({super.key});

  @override
  ConsumerState<SearchChatsView> createState() => _SearchChatsViewState();
}

class _SearchChatsViewState extends ConsumerState<SearchChatsView> {
  String _q = '';

  void _openChat(ChatListItem chat) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go('/chat/${chat.id}');
  }

  /// The plan opens in the Plan pane of a new home: beside it on wide screens, as a sheet on phones.
  void _openPlan(PlanSummary plan) {
    final router = GoRouter.of(context);
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    ref.read(sidePanelProvider(homePanelKey).notifier).openPlan(plan.id);
    Navigator.of(context).pop();
    router.go(AppPaths.home);
    if (!wide) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final home = router.routerDelegate.navigatorKey.currentContext;
        if (home != null && home.mounted) unawaited(showSidePanelSheet(home, homePanelKey));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final q = _q.trim();
    final nothingYet = ref.watch(recentsProvider).value?.items.isEmpty ?? false;

    Widget note(String text) => Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppText.body.copyWith(color: palette.textSecondary),
      ),
    );

    final Widget body;
    if (nothingYet) {
      body = note('Nothing to search yet.');
    } else if (q.length < 2) {
      body = note('Type at least 2 letters');
    } else {
      body = switch (ref.watch(chatSearchProvider(q))) {
        AsyncData(:final value) when value.isEmpty => note("Nothing found for '$q'"),
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          children: [
            if (value.chats.isNotEmpty) ...[
              const SidebarLabel('Chats'),
              for (final chat in value.chats)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: SidebarItem(
                    icon: AppIcons.newChat,
                    label: chat.title ?? untitledChat,
                    onTap: () => _openChat(chat),
                  ),
                ),
            ],
            if (value.plans.isNotEmpty) ...[
              const SidebarLabel('Plans'),
              for (final plan in value.plans)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: PlanCardTile(plan: plan, onOpen: () => _openPlan(plan)),
                ),
            ],
          ],
        ),
        AsyncError() => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            note("Couldn't search your chats."),
            OutlinedButton(onPressed: () => ref.invalidate(chatSearchProvider(q)), child: const Text('Try again')),
          ],
        ),
        _ => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      };
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  autofocus: true,
                  enabled: !nothingYet,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search chats and plans',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: AppIcon(AppIcons.search, size: 18, color: palette.textSecondary),
                    ),
                  ),
                  onChanged: (text) => setState(() => _q = text),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: AppIcon(AppIcons.x, color: palette.textSecondary),
              ),
            ],
          ),
        ),
        Flexible(child: body),
      ],
    );
  }
}
