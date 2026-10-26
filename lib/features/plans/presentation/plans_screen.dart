import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/page_frame.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      children: [
        Text('My plans', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xl),
        const EmptyState(
          icon: Icons.work_outline,
          title: 'No plans yet',
          message: 'Weighted search and complete itineraries arrive in Sprints 3 and 4.',
        ),
      ],
    );
  }
}
