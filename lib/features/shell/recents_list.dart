import 'dart:async';

import 'package:chocomousse/app/router.dart';
import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/skeleton.dart';
import 'package:chocomousse/features/chat/application/recents.dart';
import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/chat/data/chat_repository.dart';
import 'package:chocomousse/features/shell/widgets/sidebar_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The words a chat without a title shows.
const untitledChat = 'New chat';

/// RECENTS in the sidebar and the drawer (spec 008 US5): the chats by title, the open one active, each with Rename
/// and Delete; Show more; how long chats are kept. Hidden while there are no chats. [onChosen] runs after a chat is
/// opened (the drawer closes).
class RecentsList extends ConsumerWidget {
  const RecentsList({required this.location, this.onChosen, super.key});

  final String location;
  final VoidCallback? onChosen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final recents = ref.watch(recentsProvider);
    final List<Widget> rows;
    switch (recents) {
      case AsyncData(:final value) when value.items.isEmpty:
        return const SizedBox.shrink();
      case AsyncData(:final value):
        rows = [
          for (final item in value.items)
            _RecentRow(item: item, active: location == '/chat/${item.id}', onChosen: onChosen),
          if (value.loadingMore)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Center(child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (value.next != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: () => unawaited(_loadMore(context, ref)), child: const Text('Show more')),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, AppSpacing.sm, 10, AppSpacing.sm),
            child: Text(
              'Chats are kept for ${value.keepDays} days.',
              style: AppText.micro.copyWith(color: palette.textTertiary),
            ),
          ),
        ];
      case AsyncError():
        rows = [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text("Couldn't load your chats", style: AppText.small.copyWith(color: palette.textSecondary)),
                ),
                TextButton(onPressed: () => ref.invalidate(recentsProvider), child: const Text('Try again')),
              ],
            ),
          ),
        ];
      case _:
        rows = [
          for (final width in const [180.0, 140.0, 200.0])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SkeletonBox(width: width, height: 14),
              ),
            ),
        ];
    }
    return ListView(padding: EdgeInsets.zero, children: [const SidebarLabel('Recents'), ...rows]);
  }

  Future<void> _loadMore(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(recentsProvider.notifier).loadMore();
    } on Object {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't load more chats.")));
    }
  }
}

enum _ChatAction { rename, delete }

/// A chat of Recents. Its ⋯ shows on hover, when active, and on long-press.
class _RecentRow extends ConsumerStatefulWidget {
  const _RecentRow({required this.item, required this.active, this.onChosen});

  final ChatListItem item;
  final bool active;
  final VoidCallback? onChosen;

  @override
  ConsumerState<_RecentRow> createState() => _RecentRowState();
}

class _RecentRowState extends ConsumerState<_RecentRow> {
  final _menu = GlobalKey<PopupMenuButtonState<_ChatAction>>();
  bool _hovered = false;

  String get _title => widget.item.title ?? untitledChat;

  Future<void> _act(_ChatAction action) async {
    switch (action) {
      case _ChatAction.rename:
        await _rename();
      case _ChatAction.delete:
        await _delete();
    }
  }

  Future<void> _rename() async {
    final messenger = ScaffoldMessenger.of(context);
    final title = await showDialog<String>(
      context: context,
      builder: (_) => RenameChatDialog(initial: widget.item.title ?? ''),
    );
    if (title == null || !mounted) return;
    try {
      await ref.read(recentsProvider.notifier).rename(widget.item.id, title);
    } on ChatFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    } on Object {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't rename this chat.")));
    }
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this chat?'),
        content: const Text('Plans built in it stay.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final wasOpen = widget.active;
    try {
      await ref.read(recentsProvider.notifier).delete(widget.item.id);
      if (wasOpen) router.go(AppPaths.home);
    } on Object {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't delete this chat.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final menu = PopupMenuButton<_ChatAction>(
      key: _menu,
      tooltip: 'More for $_title',
      padding: EdgeInsets.zero,
      iconSize: 16,
      icon: AppIcon(AppIcons.more, size: 16, color: palette.textSecondary),
      onSelected: (action) => unawaited(_act(action)),
      itemBuilder: (_) => const [
        PopupMenuItem(value: _ChatAction.rename, child: Text('Rename')),
        PopupMenuItem(value: _ChatAction.delete, child: Text('Delete')),
      ],
    );
    final showMenu = _hovered || widget.active;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onLongPress: () => _menu.currentState?.showButtonMenu(),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              SidebarItem(
                label: _title,
                active: widget.active,
                onTap: () {
                  widget.onChosen?.call();
                  GoRouter.of(context).go('/chat/${widget.item.id}');
                },
                trailing: const SizedBox(width: 28),
              ),
              // Beside the item, not in it, so screen readers reach it; kept in the tree for a long-press.
              SizedBox.square(
                dimension: 32,
                child: Visibility.maintain(visible: showMenu, child: menu),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rename a chat: 1–40 characters after trimming.
class RenameChatDialog extends StatefulWidget {
  const RenameChatDialog({required this.initial, super.key});

  final String initial;

  @override
  State<RenameChatDialog> createState() => _RenameChatDialogState();
}

class _RenameChatDialogState extends State<RenameChatDialog> {
  late final _field = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  bool get _valid {
    final title = _field.text.trim();
    return title.isNotEmpty && title.length <= 40;
  }

  void _save() {
    if (_valid) Navigator.of(context).pop(_field.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rename chat'),
    content: TextField(
      controller: _field,
      autofocus: true,
      maxLength: 40,
      decoration: const InputDecoration(labelText: 'Title', helperText: '1–40 characters'),
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _save(),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(onPressed: _valid ? _save : null, child: const Text('Save')),
    ],
  );
}
