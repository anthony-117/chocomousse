import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/page_frame.dart';
import '../application/destination_providers.dart';
import 'widgets/common.dart';
import 'widgets/trip_chips.dart';

/// Destination search (designs 03 / W1 search bar).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _debounce = Duration(milliseconds: 300);

  final _controller = TextEditingController();
  Timer? _timer;
  String _query = '';

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(_debounce, () => setState(() => _query = value.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final results = ref.watch(destinationSearchProvider(_query));

    return PageFrame(
      children: [
        Row(
          children: [
            const BackCircleButton(),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                decoration: const InputDecoration(
                  hintText: 'Search a city',
                  prefixIcon: Icon(Icons.search, color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        if (_query.length >= 2) ...[
          Text('DESTINATIONS', style: textTheme.labelSmall),
          const SizedBox(height: AppSpacing.sm),
          results.when(
            loading: () => const LoadingBlock(height: 80),
            error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(destinationSearchProvider(_query))),
            data: (items) => items.isEmpty
                ? Text('No city matches "$_query".', style: textTheme.bodyLarge)
                : Column(
                    children: [
                      for (final d in items)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.place_outlined, color: AppColors.primary),
                          title: Text(d.name, style: textTheme.labelLarge),
                          subtitle: Text('${d.subtitle} ${d.flag ?? ''}'.trim(), style: textTheme.bodySmall),
                          onTap: () => context.push('/discover/destination/${d.id}'),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        Text('TRAVELLING WITH', style: textTheme.labelSmall),
        const SizedBox(height: AppSpacing.sm),
        const TripChips(),
      ],
    );
  }
}
