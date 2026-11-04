import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/features/assistant/data/assistant_models.dart';
import 'package:chocomousse/features/assistant/data/assistant_repository.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/flights/application/flight_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The city a chat is about, when it was opened from that city's overview.
typedef ChatCity = ({String id, String name});

class ChatState {
  const ChatState({this.messages = const [], this.city, this.sending = false, this.error});

  final List<ChatMessage> messages;
  final ChatCity? city;
  final bool sending;

  /// Why the last request failed, shown under the message marked "Not sent".
  final String? error;

  bool get isEmpty => messages.isEmpty;

  /// Try again applies to a message that wasn't sent, or to an answer that was only a warning.
  bool get canRetry => !sending && messages.isNotEmpty && (messages.last.notSent || messages.last.isWarningOnly);

  ChatState copyWith({List<ChatMessage>? messages, bool? sending, String? error, bool clearError = false}) => ChatState(
    messages: messages ?? this.messages,
    city: city,
    sending: sending ?? this.sending,
    error: clearError ? null : error ?? this.error,
  );
}

/// The chat for this app session (spec 003-assistant-screen, FR-003). Kept while the traveller moves between tabs;
/// a reload of the web app starts a new one. Never retries on its own (constitution V).
class ChatController extends Notifier<ChatState> {
  @override
  ChatState build() => const ChatState();

  /// Sends [text] as the traveller and adds the answer. Does nothing while a message is on its way.
  Future<void> send(String text) async {
    final message = text.trim();
    if (message.isEmpty || state.sending) return;
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(role: ChatRole.traveller, text: message),
      ],
    );
    await _ask();
  }

  /// Sends the last traveller message again, after a failure or a warning-only answer.
  Future<void> retry() async {
    if (!state.canRetry) return;
    final messages = [...state.messages];
    if (messages.last.isWarningOnly) messages.removeLast();
    messages[messages.length - 1] = messages.last.copyWith(notSent: false);
    state = state.copyWith(messages: messages, clearError: true);
    await _ask();
  }

  /// Clears the conversation and the city it was about.
  void newChat() => state = const ChatState();

  /// Starts a chat about [city], unless the current chat is already about it.
  void startFor(ChatCity city) {
    if (state.city?.id == city.id) return;
    state = ChatState(city: city);
  }

  Future<void> _ask() async {
    state = state.copyWith(sending: true, clearError: true);
    try {
      final reply = await ref.read(assistantRepositoryProvider).ask(state.messages, _context());
      if (!ref.mounted) return;
      final answer = ChatMessage(
        role: ChatRole.assistant,
        text: reply.text,
        cards: reply.cards,
        warnings: reply.warnings,
      );
      state = state.copyWith(messages: [...state.messages, answer], sending: false);
    } on Object catch (error) {
      if (!ref.mounted) return;
      final messages = [...state.messages];
      messages[messages.length - 1] = messages.last.copyWith(notSent: true);
      state = state.copyWith(messages: messages, sending: false, error: describeApiError(error));
    }
  }

  /// The shared trip settings, the chat's city and the chosen departure city.
  ChatContext _context() {
    final trip = ref.read(tripSettingsProvider);
    return ChatContext(
      destinationId: state.city?.id,
      from: trip.from,
      to: trip.to,
      adults: trip.adults,
      passport: trip.passport,
      currency: trip.currency,
      originId: ref.read(departureCityProvider)?.id,
    );
  }
}

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(ChatController.new);
