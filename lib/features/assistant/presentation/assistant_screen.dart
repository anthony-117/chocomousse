import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/widgets/app_logo.dart';
import 'package:chocomousse/features/assistant/application/card_opener.dart';
import 'package:chocomousse/features/assistant/application/chat_controller.dart';
import 'package:chocomousse/features/assistant/data/assistant_models.dart';
import 'package:chocomousse/features/assistant/presentation/widgets/action_card.dart';
import 'package:chocomousse/features/assistant/presentation/widgets/chat_bubble.dart';
import 'package:chocomousse/features/assistant/presentation/widgets/chat_input.dart';
import 'package:chocomousse/features/assistant/presentation/widgets/suggestion_chips.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/shell/floating_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// The Assistant tab (Figma 09 on phones, the chat column of W6 on wide screens). Plan editing and the list of saved
/// conversations wait for the itinerary and accounts (spec 003-assistant-screen).
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  /// Shown under the greeting (FR-006; ADR 0005: the free tier may use prompts for training).
  static const privacyNotice =
      "Answers come from Google Gemini using TravelGenie's data. Don't share personal details.";

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Keeps the newest message in view.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _open(AssistantCard card) async {
    await ref.read(cardOpenerProvider).apply(card);
    if (mounted) context.go(card.route);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(chatControllerProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length || previous?.sending != next.sending) _scrollToEnd();
    });
    final chat = ref.watch(chatControllerProvider);
    final controller = ref.read(chatControllerProvider.notifier);
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final sidePadding = wide ? 40.0 : AppSpacing.xl;

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: EdgeInsets.fromLTRB(sidePadding, wide ? 32 : AppSpacing.xl, sidePadding, 0),
            child: Column(
              children: [
                _Header(city: chat.city, onNewChat: chat.isEmpty && chat.city == null ? null : controller.newChat),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    children: [
                      if (chat.isEmpty) _Welcome(city: chat.city),
                      for (final (i, message) in chat.messages.indexed)
                        _MessageView(
                          message: message,
                          // The error is the last request's, so only the last message shows it.
                          error: i == chat.messages.length - 1 ? chat.error : null,
                          onRetry: i == chat.messages.length - 1 && chat.canRetry ? controller.retry : null,
                          onOpen: _open,
                        ),
                      if (chat.sending) ...[const TypingBubble(), const SizedBox(height: AppSpacing.md)],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (!chat.sending) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SuggestionChips(cityName: chat.city?.name, onPick: controller.send),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                ChatInput(enabled: !chat.sending, onSend: controller.send),
                // Room for the floating nav on phones.
                SizedBox(height: wide ? AppSpacing.xxl : FloatingNav.height + AppSpacing.xl + AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.city, required this.onNewChat});

  final ChatCity? city;
  final VoidCallback? onNewChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final trip = ref.watch(tripSettingsProvider);
    final day = DateFormat('d MMM');
    final name = city?.name;
    final about = name == null
        ? 'Ask about any city'
        : 'About $name · ${day.format(trip.from)} – ${day.format(trip.to)}';
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;

    return Row(
      children: [
        const AppLogoMark(size: 44),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assistant', style: textTheme.headlineSmall),
              Text(about, style: textTheme.bodySmall),
            ],
          ),
        ),
        // On phones the label would squeeze the trip line; the icon keeps its name as a tooltip.
        if (onNewChat != null && wide)
          TextButton.icon(
            onPressed: onNewChat,
            icon: const Icon(Icons.add_comment_outlined),
            label: const Text('New chat'),
          )
        else if (onNewChat != null)
          IconButton(tooltip: 'New chat', onPressed: onNewChat, icon: const Icon(Icons.add_comment_outlined)),
      ],
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.city});

  final ChatCity? city;

  @override
  Widget build(BuildContext context) {
    final name = city?.name;
    final greeting = name == null
        ? "Hi! Ask me about any city: visas, weather, money, safety, places to see and eat, events, flights and hotels. I'll answer with TravelGenie's data."
        : 'Hi! Ask me anything about your trip to $name: visas, weather, money, safety, places, events, flights and hotels.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChatBubble.text(ChatMessage(role: ChatRole.assistant, text: greeting)),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: Text(AssistantScreen.privacyNotice, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.message, required this.error, required this.onRetry, required this.onOpen});

  final ChatMessage message;
  final String? error;
  final VoidCallback? onRetry;
  final ValueChanged<AssistantCard> onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: message.role == ChatRole.traveller ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (message.isWarningOnly)
            WarningBubble(warnings: message.warnings, onRetry: onRetry)
          else ...[
            ChatBubble.text(message),
            if (message.notSent) NotSentNote(error: error, onRetry: onRetry),
            for (final card in message.cards) ...[
              const SizedBox(height: AppSpacing.sm),
              ActionCard(card: card, onOpen: () => onOpen(card)),
            ],
            if (message.warnings.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              ReplyWarnings(message.warnings),
            ],
          ],
        ],
      ),
    );
  }
}
