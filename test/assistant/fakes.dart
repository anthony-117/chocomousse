import 'dart:async';

import 'package:chocomousse/features/assistant/data/assistant_models.dart';
import 'package:chocomousse/features/assistant/data/assistant_repository.dart';

/// A card as pamplemousse returns it.
Map<String, Object?> cardJson({
  String kind = 'hotels',
  String title = 'Hotels in Rome',
  String subtitle = '10 – 15 Apr · 2 adults',
  String? from = '2027-04-10',
  String? to = '2027-04-15',
  int? adults = 2,
  String? originId,
  String? category,
}) => {
  'kind': kind,
  'destinationId': '3169070',
  'title': title,
  'subtitle': subtitle,
  'from': from,
  'to': to,
  'adults': adults,
  'originId': originId,
  'category': category,
};

AssistantReply reply(String text, {List<Map<String, Object?>> cards = const [], List<String> warnings = const []}) =>
    AssistantReply.fromJson({'text': text, 'cards': cards, 'warnings': warnings});

/// Answers each message with the next queued reply (or [fallback]), and remembers what it was sent.
/// [pending], when set, holds the answer until the test completes it, to check the typing state.
class FakeAssistantRepository implements AssistantRepository {
  FakeAssistantRepository({List<Object>? replies}) : _replies = [...?replies];

  /// Each item is an [AssistantReply] to answer with, or an error to throw.
  final List<Object> _replies;
  final requests = <({List<ChatMessage> messages, ChatContext context})>[];
  Completer<AssistantReply>? pending;
  AssistantReply fallback = reply('Here you go.');

  void answerWith(Object replyOrError) => _replies.add(replyOrError);

  @override
  Future<AssistantReply> ask(List<ChatMessage> conversation, ChatContext context) {
    requests.add((messages: [...conversation], context: context));
    final waiting = pending;
    if (waiting != null) return waiting.future;
    final next = _replies.isEmpty ? fallback : _replies.removeAt(0);
    return next is AssistantReply ? Future.value(next) : Future.error(next);
  }
}
