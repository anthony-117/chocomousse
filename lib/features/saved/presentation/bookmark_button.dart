import 'dart:async';

import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/features/chat/application/chat_trip.dart';
import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/saved/application/saved_providers.dart';
import 'package:chocomousse/features/saved/data/saved_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Saves or removes a hotel, place or event (spec 008 US6): a filled bookmark when saved, outlined when not. On a
/// card's photo it is a round icon; in the Details footer, [labelled] adds "Save" or "Saved". Nothing for other kinds.
class BookmarkButton extends ConsumerWidget {
  const BookmarkButton({required this.card, this.labelled = false, super.key});

  final AssistantCard card;
  final bool labelled;

  Future<void> _toggle(BuildContext context, WidgetRef ref, String? tripCity) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failure = await ref.read(savedIdsProvider.notifier).toggle(card, fallbackDestinationId: tripCity);
    if (failure != null) messenger?.showSnackBar(SnackBar(content: Text(failure)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = SavedKind.of(card);
    if (kind == null) return const SizedBox.shrink();
    final palette = context.palette;
    final saved = ref.watch(savedIdsProvider.select((ids) => ids.value?.contains(kind, card.id) ?? false));
    // Watched, so the trip is seeded by the time the bookmark is tapped.
    final tripCity = ref.watch(chatTripProvider.select((s) => s.trip.destinationId));
    final tooltip = saved ? 'Remove ${card.title} from Saved' : 'Save ${card.title}';
    void onPressed() => unawaited(_toggle(context, ref, tripCity));

    if (labelled) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: AppIcon(saved ? AppIcons.bookmarkFilled : AppIcons.bookmark, size: 18, color: palette.brandPrimary),
        label: Text(saved ? 'Saved' : 'Save'),
      );
    }
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(backgroundColor: palette.bgSurface.withValues(alpha: 0.9)),
      icon: AppIcon(
        saved ? AppIcons.bookmarkFilled : AppIcons.bookmark,
        size: 18,
        color: saved ? palette.brandPrimary : palette.textPrimary,
      ),
    );
  }
}
