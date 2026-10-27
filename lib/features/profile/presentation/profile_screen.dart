import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/page_frame.dart';
import 'package:chocomousse/env.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PageFrame(
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person_outline, color: AppColors.onPrimary, size: 32),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Guest', style: textTheme.titleLarge),
                  Text('Sign-in arrives in a later sprint', style: textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        const BackendStatusCard(),
      ],
    );
  }
}

/// Shows whether the app can reach pamplemousse (Sprint 0 end-to-end check).
class BackendStatusCard extends ConsumerWidget {
  const BackendStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ping = ref.watch(pingProvider);

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Backend', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          ping.when(
            loading: () => const LinearProgressIndicator(),
            data: (info) => Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Connected to ${info.name} ${info.shortVersion} (${info.environment})',
                    style: textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            error: (error, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text('Cannot reach ${Env.apiBaseUrl}', style: textTheme.bodyLarge)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(onPressed: () => ref.invalidate(pingProvider), child: const Text('Try again')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
