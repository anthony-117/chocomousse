import 'package:chocomousse/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Ready-made questions above the input (Suggestions in Figma 09/W6). About the chat's city when it has one.
class SuggestionChips extends StatelessWidget {
  const SuggestionChips({required this.cityName, required this.onPick, super.key});

  final String? cityName;
  final ValueChanged<String> onPick;

  static List<String> forCity(String? city) => city == null
      ? const ['Is Lisbon safe to visit?', 'Weather in Rome next week', 'Best restaurants in Paris']
      : const ['Do I need a visa?', "What's the weather like?", 'Cheaper hotels', "What's on during my trip?"];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final question in forCity(cityName)) ...[
            ActionChip(label: Text(question), onPressed: () => onPick(question)),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
