import 'dart:async';

import 'package:chocomousse/app/router.dart';
import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/skeleton.dart';
import 'package:chocomousse/features/chat/application/chat_controller.dart';
import 'package:chocomousse/features/chat/data/chat_repository.dart';
import 'package:chocomousse/features/chat/presentation/composer.dart';
import 'package:chocomousse/features/chat/presentation/widgets/chat_bits.dart';
import 'package:chocomousse/features/chat/presentation/widgets/chat_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// A chat (spec 008 US1, W2 and M2): the messages, the steps of the answer being written, what to ask next and the
/// composer, with the side panel beside it on wide screens.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.chatId, super.key});

  final String chatId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scroll = ScrollController();

  /// Follows the newest step or answer until the traveller scrolls up.
  bool _follow = true;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    if (!_follow) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is UserScrollNotification || notification is ScrollUpdateNotification) {
      final position = notification.metrics;
      if (notification is UserScrollNotification || (notification as ScrollUpdateNotification).dragDetails != null) {
        _follow = position.pixels >= position.maxScrollExtent - 48;
      }
    }
    return false;
  }

  Future<void> _share() async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: '/chat/${widget.chatId}'));
    messenger.showSnackBar(const SnackBar(content: Text('Link to the chat copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final key = widget.chatId;
    final state = ref.watch(chatProvider(key));
    final controller = ref.read(chatProvider(key).notifier);
    ref.listen(chatProvider(key), (previous, next) {
      if (previous?.messages.length != next.messages.length ||
          previous?.pending?.steps.length != next.pending?.steps.length) {
        _toBottom();
      }
    });

    final last = state.messages.lastOrNull;
    final suggestions = last != null && !last.isTraveller && !state.isSending ? last.suggestions : const <String>[];
    final pending = state.pending;

    Widget list;
    if (state.messages.isEmpty && state.status == ChatStatus.loading) {
      list = const _MessagesSkeleton();
    } else if (state.messages.isEmpty && state.failure is ChatNotFound) {
      list = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('This chat has expired', style: AppText.title.copyWith(color: palette.textPrimary)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Chats are deleted some time after their last message.',
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: () => context.go(AppPaths.home), child: const Text('New trip chat')),
            ],
          ),
        ),
      );
    } else if (state.messages.isEmpty && state.status == ChatStatus.failed) {
      list = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.failure?.message ?? "Couldn't open this chat.",
              style: AppText.body.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: () => unawaited(controller.load()), child: const Text('Try again')),
          ],
        ),
      );
    } else {
      list = NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.lg),
          children: [
            ChatColumn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final message in state.messages) ...[
                    if (message.isTraveller) ...[
                      UserBubble(message),
                      if (identical(message, pending?.message)) ...[
                        const SizedBox(height: AppSpacing.md),
                        for (final step in pending!.steps) ToolStepLine(step: step, chatKey: key),
                        if (state.isSending) const WorkingIndicator(),
                      ],
                      if (message.notSent && identical(message, last))
                        _FailureRow(
                          message: state.failure?.message ?? "This message wasn't answered.",
                          onRetry: state.canRetry ? () => unawaited(controller.retry()) : null,
                        ),
                    ] else
                      AnswerView(message: message, chatKey: key),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  if (state.status == ChatStatus.busyElsewhere)
                    const WorkingIndicator(label: 'Still answering on another device…'),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide)
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: palette.borderDefault)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    state.title ?? 'New chat',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong.copyWith(color: palette.textPrimary),
                  ),
                ),
                IconButton(
                  tooltip: 'Share',
                  onPressed: () => unawaited(_share()),
                  icon: AppIcon(AppIcons.share, color: palette.textSecondary),
                ),
              ],
            ),
          ),
        Expanded(child: list),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
            child: ChatColumn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (suggestions.isNotEmpty) ...[
                    SuggestionChips(suggestions: suggestions, onSend: (text) => unawaited(controller.send(text))),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Composer(
                    panelKey: key,
                    sending: state.isSending || state.status == ChatStatus.busyElsewhere,
                    onSend: (text) => unawaited(controller.send(text)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    return ChatLayout(chatKey: key, child: column);
  }
}

/// While a chat opens: three message blocks, a question on the right and answers on the left.
class _MessagesSkeleton extends StatelessWidget {
  const _MessagesSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.xl),
    children: const [
      ChatColumn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(alignment: Alignment.centerRight, child: SkeletonBox(width: 260, height: 44)),
            SizedBox(height: AppSpacing.xl),
            SkeletonBox(height: 120),
            SizedBox(height: AppSpacing.xl),
            Align(alignment: Alignment.centerRight, child: SkeletonBox(width: 200, height: 44)),
          ],
        ),
      ),
    ],
  );
}

/// Under a message that wasn't answered: why, and Try again.
class _FailureRow extends StatelessWidget {
  const _FailureRow({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              textAlign: TextAlign.right,
              style: AppText.small.copyWith(color: palette.statusWarning),
            ),
          ),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
