import 'dart:async';

import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/features/account/data/profile_repository.dart';
import 'package:chocomousse/features/chat/data/chat_events.dart';
import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/chat/data/chat_transport.dart';
import 'package:chocomousse/features/chat/data/sse_decoder.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Why a chat request was refused, in the words the screens show (data-model "Refusals").
sealed class ChatFailure implements Exception {
  const ChatFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 409 `chat-busy`: an answer is still running for this chat, on another device.
class ChatBusy extends ChatFailure {
  const ChatBusy() : super('Still answering on another device…');
}

/// 409 `chat-full`: the chat has 200 messages.
class ChatFull extends ChatFailure {
  const ChatFull([super.message = 'This chat is full. Start a new chat to carry on.']);
}

/// 404: the chat expired, was deleted, or isn't the traveller's.
class ChatNotFound extends ChatFailure {
  const ChatNotFound() : super('This chat has expired.');
}

/// 429: too many messages; Try again works after [retryAfter].
class TooManyMessages extends ChatFailure {
  const TooManyMessages(this.retryAfter) : super('Too many messages. Wait a minute and try again.');

  final Duration? retryAfter;
}

/// 400: the API refused a value; [field] is the API's name for it.
class FieldError extends ChatFailure {
  const FieldError(this.field, super.message);

  final String field;
}

/// Anything else: the server can't be reached or can't answer.
class ChatUnavailable extends ChatFailure {
  const ChatUnavailable(super.message);
}

/// The chat routes of API spec 010. Tests replace it through [chatRepositoryProvider], or its transport.
class ChatRepository {
  ChatRepository(this._dio, this._transport, {this.watchdog = const Duration(seconds: 30)});

  final Dio _dio;
  final ChatTransport _transport;

  /// The answer is treated as lost after this long without a byte (the server pings every 10 s).
  final Duration watchdog;

  /// Recents, latest first. [limit] is 1–100.
  Future<ChatPage> list({String? before, int limit = 30}) async {
    assert(limit >= 1 && limit <= 100, 'limit is 1–100');
    final response = await _call(
      () => _dio.get<Map<String, dynamic>>('/assistant/chats', queryParameters: {'limit': limit, 'before': ?before}),
    );
    return ChatPage.fromJson(response.data!);
  }

  Future<Chat> get(String id) async {
    final response = await _call(() => _dio.get<Map<String, dynamic>>('/assistant/chats/$id'));
    return Chat.fromJson(response.data!);
  }

  /// Renames the chat; [title] is 1–40 characters after trimming.
  Future<ChatListItem> rename(String id, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty || trimmed.length > 40) throw const FieldError('title', 'Use 1 to 40 characters.');
    final response = await _call(
      () => _dio.patch<Map<String, dynamic>>('/assistant/chats/$id', data: {'title': trimmed}),
    );
    return ChatListItem.fromJson(response.data!);
  }

  Future<void> delete(String id) => _call(() => _dio.delete<void>('/assistant/chats/$id'));

  /// Chats and plans matching [q], which is 2–100 characters.
  Future<ChatSearchResult> search(String q) async {
    final trimmed = q.trim();
    if (trimmed.length < 2 || trimmed.length > 100) return const ChatSearchResult(chats: [], plans: []);
    final response = await _call(
      () => _dio.get<Map<String, dynamic>>('/assistant/chats/search', queryParameters: {'q': trimmed}),
    );
    return ChatSearchResult.fromJson(response.data!);
  }

  /// Sends a message: to a new chat without [chatId], else to that chat. A refusal is thrown as a [ChatFailure]
  /// before any event; once the stream runs, failures end it with [AnswerFailed].
  Stream<ChatEvent> send({required ChatRequest request, String? chatId}) async* {
    final path = chatId == null ? '/assistant/chats' : '/assistant/chats/$chatId/messages';
    final Stream<List<int>> bytes;
    try {
      bytes = await _transport.post(path, request.toJson());
    } on ChatRefused catch (refused) {
      throw _refusal(refused);
    } on DioException catch (e) {
      throw ChatUnavailable(describeApiError(e));
    }

    try {
      await for (final sse in bytes.timeout(watchdog).transform(const SseDecoder())) {
        final ChatEvent? event;
        try {
          event = ChatEvent.fromSse(sse);
        } on FormatException {
          continue;
        }
        if (event == null) continue;
        yield event;
        if (event is AnswerDone || event is AnswerFailed) return;
      }
    } on Object {
      // A watchdog timeout or a dropped connection: the answer is lost, below.
    }
    yield const AnswerFailed(AnswerFailed.lost);
  }

  static ChatFailure _refusal(ChatRefused refused) {
    final message = refused.problem?['detail'] as String? ?? refused.problem?['title'] as String?;
    return switch (refused.statusCode) {
      409 when refused.code == 'chat-busy' => const ChatBusy(),
      409 when refused.code == 'chat-full' => message == null ? const ChatFull() : ChatFull(message),
      404 => const ChatNotFound(),
      429 => TooManyMessages(refused.retryAfter),
      400 => _fieldError(refused.problem) ?? ChatUnavailable(message ?? 'The server could not handle this message.'),
      401 => const ChatUnavailable('Sign in again to continue.'),
      403 => const ChatUnavailable('Confirm your email first.'),
      _ => const ChatUnavailable("The assistant can't answer right now. Try again in a moment."),
    };
  }

  static FieldError? _fieldError(Map<String, Object?>? problem) {
    final errors = problem?['errors'];
    if (errors is! Map || errors.isEmpty) return null;
    final first = errors.entries.first;
    final value = first.value;
    return FieldError(
      first.key.toString(),
      value is List && value.isNotEmpty ? value.first.toString() : 'Check this value.',
    );
  }

  static Future<Response<T>> _call<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) throw const ChatNotFound();
      final fields = ProfileRepository.fieldErrorsOf(e);
      if (fields != null && fields.isNotEmpty) throw FieldError(fields.keys.first, fields.values.first);
      rethrow;
    }
  }
}

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(dioProvider), ref.watch(chatTransportProvider)),
);
