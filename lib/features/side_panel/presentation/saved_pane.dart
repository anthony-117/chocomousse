import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/core/widgets/skeleton.dart';
import 'package:chocomousse/features/destination/presentation/widgets/offers.dart';
import 'package:chocomousse/features/saved/application/saved_providers.dart';
import 'package:chocomousse/features/saved/data/saved_models.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const kSavedEmpty = 'Tap the bookmark on a hotel, place or event to keep it here.';

/// The Saved pane (spec 008 US6): Hotels, Places and Events, newest first. A row opens its item in Details.
class SavedPane extends ConsumerWidget {
  const SavedPane({required this.chatKey, super.key});

  final String chatKey;

  void _open(BuildContext context, WidgetRef ref, SavedItem item) {
    final card = item.card;
    if (card == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text("This item can't be opened here. Ask the assistant to find it again.")),
      );
      return;
    }
    ref.read(sidePanelProvider(chatKey).notifier).openCard(card);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final saved = ref.watch(savedProvider);
    return saved.when(
      skipLoadingOnRefresh: true,
      loading: () => ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          for (var i = 0; i < 4; i++) ...[
            const Row(
              children: [
                SkeletonBox(width: 56, height: 56, radius: AppRadius.md),
                SizedBox(width: AppSpacing.md),
                Expanded(child: SkeletonBox(height: 32)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(describeApiError(e), style: AppText.body.copyWith(color: palette.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(onPressed: () => ref.invalidate(savedProvider), child: const Text('Try again')),
          ],
        ),
      ),
      data: (list) {
        if (list.items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(kSavedEmpty, style: AppText.body.copyWith(color: palette.textSecondary)),
          );
        }
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          children: [
            for (final kind in SavedKind.values)
              if (list.of(kind) case final items when items.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xs),
                  child: Text(
                    kind.groupLabel.toUpperCase(),
                    style: AppText.micro.copyWith(color: palette.textTertiary),
                  ),
                ),
                for (final item in items) _SavedRow(item: item, onTap: () => _open(context, ref, item)),
              ],
          ],
        );
      },
    );
  }
}

class _SavedRow extends StatelessWidget {
  const _SavedRow({required this.item, required this.onTap});

  final SavedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: [item.name, if (item.destinationName.isNotEmpty) item.destinationName].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: SizedBox.square(dimension: 56, child: OfferPhoto(url: item.imageUrl)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong.copyWith(color: palette.textPrimary),
                    ),
                    if (item.destinationName.isNotEmpty)
                      Text(item.destinationName, style: AppText.small.copyWith(color: palette.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
