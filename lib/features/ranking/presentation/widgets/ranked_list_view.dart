import 'dart:async';

import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/page_frame.dart';
import 'package:chocomousse/features/destination/presentation/widgets/common.dart';
import 'package:chocomousse/features/destination/presentation/widgets/offers.dart';
import 'package:chocomousse/features/ranking/data/ranking_models.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/ranked_card.dart';
import 'package:chocomousse/features/ranking/presentation/widgets/why_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What one kind adds to the shared list: its notes, its cards, how an offer opens, and its empty state.
class RankedKindView<T, R> {
  const RankedKindView({
    required this.noun,
    required this.notes,
    required this.card,
    required this.open,
    required this.emptyTitle,
    required this.message,
    required this.searchUrl,
    this.footer,
  });

  /// "Hotels", for the over-budget note.
  final String noun;
  final List<Widget> Function(R results) notes;
  final RankedCardData Function(T offer, R results) card;
  final void Function(T offer, R results) open;
  final String emptyTitle;
  final String? Function(R results) message;
  final String? Function(R results) searchUrl;
  final Widget? footer;
}

/// A ranked list in the API's order (FR-005), with its notes, and on wide screens the selected offer's "Why" beside it.
class RankedListView<T, R> extends StatefulWidget {
  const RankedListView({
    required this.value,
    required this.kind,
    required this.loading,
    required this.onRetry,
    required this.onSearch,
    required this.wide,
    super.key,
  });

  final AsyncValue<RankedList<T, R>> value;
  final RankedKindView<T, R> kind;
  final Widget loading;
  final VoidCallback onRetry;
  final ValueChanged<String> onSearch;
  final bool wide;

  @override
  State<RankedListView<T, R>> createState() => _RankedListViewState<T, R>();
}

class _RankedListViewState<T, R> extends State<RankedListView<T, R>> {
  String? _selected;

  void _tap(Ranked<T> item, RankedCardData data, R results) {
    final match = item.match;
    if (match == null) {
      widget.kind.open(item.offer, results);
    } else if (widget.wide) {
      setState(() => _selected = data.id);
    } else {
      unawaited(
        showModalBottomSheet<void>(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (sheet) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
              child: WhyView(
                data: data,
                match: match,
                onOpen: () {
                  Navigator.of(sheet).pop();
                  widget.kind.open(item.offer, results);
                },
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.value.when(
      skipLoadingOnReload: false,
      loading: () => widget.loading,
      error: (e, _) => Column(
        children: [
          ErrorRetryBanner(message: describeProblem(e), onRetry: widget.onRetry),
          const SizedBox(height: AppSpacing.sm),
          const RankedCardPlaceholders(animate: false),
        ],
      ),
      data: _list,
    );
  }

  Widget _list(RankedList<T, R> list) {
    final kind = widget.kind;
    final results = list.results;
    final cards = [for (final item in list.items) (item, kind.card(item.offer, results))];
    final rankingNote = list.rankingNote;

    final notes = <Widget>[...kind.notes(results), if (rankingNote != null) WarningNote(rankingNote)];

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final note in notes) ...[note, const SizedBox(height: AppSpacing.sm)],
        const SizedBox(height: AppSpacing.xs),
        if (cards.isEmpty)
          _Empty(
            title: kind.emptyTitle,
            message: kind.message(results),
            searchUrl: kind.searchUrl(results),
            onSearch: widget.onSearch,
          )
        else
          for (final (item, data) in cards) ...[
            RankedCard(
              data: data,
              match: item.match,
              selected: widget.wide && data.id == (_selected ?? cards.first.$2.id),
              onTap: () => _tap(item, data, results),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        if (list.anyOverBudget) ...[
          WarningNote('${kind.noun} that cost more than your whole budget are listed last, whatever their match.'),
          const SizedBox(height: AppSpacing.md),
        ],
        ?kind.footer,
      ],
    );

    if (!widget.wide || cards.isEmpty) return column;

    final selected = cards.firstWhere((c) => c.$2.id == _selected, orElse: () => cards.first);
    final match = selected.$1.match;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: column),
        const SizedBox(width: AppSpacing.xl),
        SizedBox(
          width: 360,
          child: match == null
              ? const SizedBox.shrink()
              : Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: context.palette.bgSurface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: context.palette.borderDefault),
                  ),
                  child: WhyView(
                    data: selected.$2,
                    match: match,
                    panel: true,
                    onOpen: () => kind.open(selected.$1.offer, list.results),
                  ),
                ),
        ),
      ],
    );
  }
}

/// The error and Try again, shown above still placeholders (FR-009).
class ErrorRetryBanner extends StatelessWidget {
  const ErrorRetryBanner({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      decoration: BoxDecoration(color: context.palette.bgApp, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: context.palette.textSecondary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodySmall)),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.message, required this.searchUrl, required this.onSearch});

  final String title;
  final String? message;
  final String? searchUrl;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final message = this.message;
    final searchUrl = this.searchUrl;
    return SoftCard(
      child: Column(
        children: [
          Text(title, style: textTheme.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(message, style: textTheme.bodySmall, textAlign: TextAlign.center),
          ],
          if (searchUrl != null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => onSearch(searchUrl), child: const Text('Search the booking site')),
            ),
          ],
        ],
      ),
    );
  }
}
