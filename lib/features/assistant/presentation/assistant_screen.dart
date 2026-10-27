import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/page_frame.dart';
import 'package:flutter/material.dart';

class AssistantScreen extends StatelessWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      children: [
        Text('Assistant', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xl),
        const EmptyState(
          icon: Icons.auto_awesome_outlined,
          title: 'Your travel assistant',
          message: 'Chatting to change your plan arrives in Sprint 5.',
        ),
      ],
    );
  }
}
