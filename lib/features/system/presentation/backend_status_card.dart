import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/page_frame.dart';
import 'package:chocomousse/env.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                Icon(Icons.check_circle, color: context.palette.statusSuccess, size: 20),
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
                    Icon(Icons.error_outline, color: context.palette.statusDanger, size: 20),
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
