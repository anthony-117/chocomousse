import 'dart:convert';

import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/chat/data/sse_decoder.dart';

/// What the answer stream says, in order: [ChatStarted], then [StepDone]s, then one [AnswerDone] or [AnswerFailed].
sealed class ChatEvent {
  const ChatEvent();

  /// The event, or null for an event name the app doesn't know (newer servers may send more).
  static ChatEvent? fromSse(SseEvent event) {
    final json = jsonDecode(event.data);
    if (json is! Map<String, dynamic>) return null;
    return switch (event.name) {
      'chat' => ChatStarted(
        chatId: json['chatId']! as String,
        title: json['title'] as String?,
        messageId: json['messageId'] as String? ?? '',
      ),
      'step' => StepDone(ToolStep.fromJson(json)),
      'final' => AnswerDone(ChatMessage.fromFinal(json), title: json['title'] as String?),
      'error' => AnswerFailed(json['warning'] as String? ?? AnswerFailed.lost),
      _ => null,
    };
  }
}

/// `event: chat`: the chat's id (new or the same) and the traveller's message id as stored.
class ChatStarted extends ChatEvent {
  const ChatStarted({required this.chatId, required this.messageId, this.title});

  final String chatId;
  final String? title;
  final String messageId;
}

/// `event: step`: a tool finished.
class StepDone extends ChatEvent {
  const StepDone(this.step);

  final ToolStep step;
}

/// `event: final`: the answer. [title] is the chat's title, set on the first answer.
class AnswerDone extends ChatEvent {
  const AnswerDone(this.message, {this.title});

  final ChatMessage message;
  final String? title;
}

/// `event: error`, or a stream that broke: the steps already shown stay, the message can be sent again.
class AnswerFailed extends ChatEvent {
  const AnswerFailed(this.warning);

  static const lost = 'The connection was lost. Try again.';

  final String warning;
}
