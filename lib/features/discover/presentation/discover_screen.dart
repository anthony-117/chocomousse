import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/page_frame.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PageFrame(
      children: [
        Text('Good morning', style: textTheme.bodySmall),
        Text('Discover', style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xl),
        const TextField(
          enabled: false,
          decoration: InputDecoration(
            hintText: 'Where to next?',
            prefixIcon: Icon(Icons.search, color: AppColors.muted),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const EmptyState(
          icon: Icons.explore_outlined,
          title: 'Destinations are on their way',
          message: 'Search, city overviews and places arrive in Sprint 1.',
        ),
      ],
    );
  }
}
