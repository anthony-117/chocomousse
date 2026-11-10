import 'dart:async';

import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/chat/data/chat_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

@immutable
class RecentsState {
  const RecentsState({required this.items, required this.keepDays, this.next, this.loadingMore = false});

  final List<ChatListItem> items;

  /// The cursor of the next page, null when every chat is shown.
  final String? next;
  final int keepDays;
  final bool loadingMore;

  RecentsState copyWith({List<ChatListItem>? items, String? next, bool clearNext = false, bool? loadingMore}) =>
      RecentsState(
        items: items ?? this.items,
        next: clearNext ? null : next ?? this.next,
        keepDays: keepDays,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// Recents in the sidebar: the latest 30 chats, then more on Show more (spec 008 US5).
class RecentsController extends AsyncNotifier<RecentsState> {
  @override
  Future<RecentsState> build() async {
    final page = await ref.watch(chatRepositoryProvider).list();
    return RecentsState(items: page.items, next: page.next, keepDays: page.keepDays);
  }

  ChatRepository get _repository => ref.read(chatRepositoryProvider);

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.next == null || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await _repository.list(before: current.next);
      if (!ref.mounted) return;
      state = AsyncData(
        current.copyWith(items: [...current.items, ...page.items], next: page.next, clearNext: page.next == null),
      );
    } on Object {
      if (!ref.mounted) return;
      state = AsyncData(current.copyWith(loadingMore: false));
      rethrow;
    }
  }

  /// Renames after the API answers; a refusal leaves the list as it was and reaches the caller.
  Future<void> rename(String id, String title) async {
    final item = await _repository.rename(id, title);
    final current = state.value;
    if (!ref.mounted || current == null) return;
    state = AsyncData(
      current.copyWith(
        items: [
          for (final i in current.items)
            if (i.id == id) item else i,
        ],
      ),
    );
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    final current = state.value;
    if (!ref.mounted || current == null) return;
    state = AsyncData(current.copyWith(items: current.items.where((i) => i.id != id).toList()));
  }
}

final recentsProvider = AsyncNotifierProvider<RecentsController, RecentsState>(RecentsController.new);

/// How long Search chats waits after the last key before it asks the API.
const chatSearchDebounce = Duration(milliseconds: 300);

/// Search chats: chats and plans matching the query. Under 2 characters it gives nothing without asking the API.
final FutureProviderFamily<ChatSearchResult, String> chatSearchProvider = FutureProvider.autoDispose
    .family<ChatSearchResult, String>((ref, q) async {
      const none = ChatSearchResult(chats: [], plans: []);
      if (q.trim().length < 2) return none;
      var disposed = false;
      ref.onDispose(() => disposed = true);
      await Future<void>.delayed(chatSearchDebounce);
      if (disposed) return none;
      return await ref.read(chatRepositoryProvider).search(q);
    });
