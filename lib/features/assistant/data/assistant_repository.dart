import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/features/assistant/data/assistant_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Calls the pamplemousse assistant endpoint. Tests replace it through [assistantRepositoryProvider].
class AssistantRepository {
  const AssistantRepository(this._dio);

  /// The API gives a whole answer at most 50 s, tool calls included; the app waits a little longer.
  static const receiveTimeout = Duration(seconds: 60);

  /// The API takes the last 20 messages.
  static const maxMessages = 20;

  final Dio _dio;

  /// Sends the conversation (messages with text only, the last [maxMessages]) and the trip.
  Future<AssistantReply> ask(List<ChatMessage> conversation, ChatContext context) async {
    final withText = conversation.where((m) => m.text.isNotEmpty).toList();
    final recent = withText.length > maxMessages ? withText.sublist(withText.length - maxMessages) : withText;
    final response = await _dio.post<Map<String, dynamic>>(
      '/assistant/messages',
      data: {
        'messages': [
          for (final m in recent) {'role': m.role.name, 'text': m.text},
        ],
        'context': context.toJson(),
      },
      options: Options(receiveTimeout: receiveTimeout),
    );
    return AssistantReply.fromJson(response.data!);
  }
}

final assistantRepositoryProvider = Provider<AssistantRepository>((ref) => AssistantRepository(ref.watch(dioProvider)));
