import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/page_frame.dart';
import 'package:chocomousse/features/destination/presentation/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Hand-picked starting points until personalised suggestions arrive (ids are GeoNames city ids).
const List<({String city, String country, String id, String theme})> _trending = [
  (id: '3169070', city: 'Rome', country: 'Italy', theme: 'Culture & food'),
  (id: '2267057', city: 'Lisbon', country: 'Portugal', theme: 'Food & ocean views'),
  (id: '745044', city: 'Istanbul', country: 'Türkiye', theme: 'History & bazaars'),
  (id: '2988507', city: 'Paris', country: 'France', theme: 'Art & cafés'),
];

/// Discover (designs 02 / W1): search entry point and trending destinations.
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;

    return PageFrame(
      children: [
        if (wide) ...[
          Center(child: Text('Where to next?', style: textTheme.displaySmall)),
          const SizedBox(height: AppSpacing.sm),
          Center(child: Text('Every flight, stay and experience — ranked for you.', style: textTheme.bodySmall)),
        ] else ...[
          Text('Good morning', style: textTheme.bodySmall),
          Text('Discover', style: textTheme.headlineSmall),
        ],
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: const _SearchPill()),
        ),
        const SizedBox(height: AppSpacing.xxl),
        const SectionTitle('Trending destinations'),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = wide ? 4 : (constraints.maxWidth >= 560 ? 2 : 1);
            const gap = AppSpacing.lg;
            final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final t in _trending)
                  SizedBox(
                    width: width,
                    child: _DestinationCard(
                      city: t.city,
                      subtitle: '${t.country} · ${t.theme}',
                      height: wide ? 280 : 180,
                      onTap: () => context.push('/discover/destination/${t.id}'),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SearchPill extends StatelessWidget {
  const _SearchPill();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Search destinations',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: () => context.push('/discover/search'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.full)),
          child: Row(
            children: [
              const Icon(Icons.search, color: AppColors.muted),
              const SizedBox(width: AppSpacing.md),
              Text('Where to next?', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({required this.city, required this.subtitle, required this.height, required this.onTap});

  final String city;
  final String subtitle;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      borderRadius: BorderRadius.circular(AppRadius.lg + 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          height: height,
          decoration: const BoxDecoration(gradient: kPhotoGradient),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(city, style: textTheme.headlineSmall?.copyWith(color: AppColors.onPrimary)),
              Text(subtitle, style: textTheme.bodySmall?.copyWith(color: AppColors.onPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}
