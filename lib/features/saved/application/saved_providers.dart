import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/saved/data/saved_models.dart';
import 'package:chocomousse/features/saved/data/saved_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a toggle that failed says when the API gave no reason of its own.
const kSaveFailed = "Couldn't save. Try again.";
const kRemoveFailed = "Couldn't remove it. Try again.";

/// The saved ids, so every card shows its bookmark (spec 008 US6). If they can't be loaded, every bookmark shows
/// empty and tapping still works.
class SavedIdsController extends AsyncNotifier<SavedIds> {
  @override
  Future<SavedIds> build() => ref.watch(savedRepositoryProvider).ids();

  SavedIds get _current => state.value ?? SavedIds.empty;

  bool isSaved(AssistantCard card) => switch (SavedKind.of(card)) {
    final kind? => _current.contains(kind, card.id),
    null => false,
  };

  /// Saves [card], or removes it when saved. The bookmark changes at once; on failure it changes back, and the
  /// message to show is returned. [fallbackDestinationId] is the chat's trip city, for a card that doesn't name one.
  Future<String?> toggle(AssistantCard card, {String? fallbackDestinationId}) async {
    final kind = SavedKind.of(card);
    if (kind == null) return null;
    final before = _current;
    final saving = !before.contains(kind, card.id);
    final destinationId = card.destinationId ?? fallbackDestinationId;
    if (saving && destinationId == null) return const NoCity().message;

    state = AsyncData(before.withId(kind, card.id, saved: saving));
    final repo = ref.read(savedRepositoryProvider);
    try {
      if (saving) {
        await repo.save(card, destinationId: destinationId!);
      } else {
        await repo.remove(kind, card.id);
      }
    } on SavedFailure catch (failure) {
      _revert(kind, card.id, saved: !saving);
      return failure.message;
    } on Object {
      _revert(kind, card.id, saved: !saving);
      return saving ? kSaveFailed : kRemoveFailed;
    }
    ref.invalidate(savedProvider);
    return null;
  }

  /// Puts back only this card's bookmark, so a toggle of another card meanwhile is kept.
  void _revert(SavedKind kind, String id, {required bool saved}) {
    if (!ref.mounted) return;
    state = AsyncData(_current.withId(kind, id, saved: saved));
  }
}

final savedIdsProvider = AsyncNotifierProvider<SavedIdsController, SavedIds>(SavedIdsController.new);

/// The Saved pane's list (`GET /saved`), reloaded after every toggle.
final FutureProvider<SavedList> savedProvider = FutureProvider.autoDispose<SavedList>(
  (ref) => ref.watch(savedRepositoryProvider).list(),
);
