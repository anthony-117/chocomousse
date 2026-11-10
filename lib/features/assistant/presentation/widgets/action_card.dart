import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/assistant/data/assistant_models.dart';
import 'package:flutter/material.dart';

/// A card under an answer (ActionCard in Figma 09/W6): what the assistant searched, opening that screen.
class ActionCard extends StatelessWidget {
  const ActionCard({required this.card, required this.onOpen, super.key});

  final AssistantCard card;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Material(
        color: context.palette.brandPrimarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.label,
                        style: textTheme.labelSmall?.copyWith(color: context.palette.brandPrimary, letterSpacing: 0.6),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(card.title, style: textTheme.titleSmall),
                      if (card.subtitle.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(card.subtitle, style: textTheme.bodySmall?.copyWith(color: context.palette.statusSuccess)),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.palette.brandPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
