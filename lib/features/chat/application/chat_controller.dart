import 'dart:async';

import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/features/chat/application/chat_trip.dart';
import 'package:chocomousse/features/chat/application/recents.dart';
import 'package:chocomousse/features/chat/data/chat_events.dart';
import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/chat/data/chat_repository.dart';
import 'package:chocomousse/features/itinerary/application/plan_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

enum ChatStatus { idle, loading, sending, busyElsewhere, failed }

/// The traveller's message being answered, and the tools run for it so far.
@immutable
class PendingTurn {
  const PendingTurn(this.message, {this.steps = const []});

  final ChatMessage message;
  final List<ToolStep> steps;

  PendingTurn withStep(ToolStep step) => PendingTurn(message, steps: [...steps, step]);
}

@immutable
class ChatState {
  const ChatState({
    this.chatId,
    this.title,
    this.messages = const [],
    this.pending,
    this.status = ChatStatus.idle,
    this.failure,
  });

  final String? chatId;
  final String? title;
  final List<ChatMessage> messages;
  final PendingTurn? pending;
  final ChatStatus status;
  final ChatFailure? failure;

  bool get isEmpty => messages.isEmpty;

  bool get isSending => status == ChatStatus.sending;

  /// Try again resends the last message when it wasn't answered.
  bool get canRetry => status == ChatStatus.failed && messages.isNotEmpty && messages.last.notSent;

  ChatState copyWith({
    String? chatId,
    String? title,
    List<ChatMessage>? messages,
    PendingTurn? pending,
    bool clearPending = false,
    ChatStatus? status,
    ChatFailure? failure,
    bool clearFailure = false,
  }) => ChatState(
    chatId: chatId ?? this.chatId,
    title: title ?? this.title,
    messages: messages ?? this.messages,
    pending: clearPending ? null : pending ?? this.pending,
    status: status ?? this.status,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}

/// One chat (spec 008 US1, US5). The key is the chat id, or null for the home's new chat. When the API gives a new
/// chat its id, the running answer moves to that chat's controller and the new chat starts empty again, so the
/// screen can switch to `/chat/{id}` without losing the answer. Never retries on its own (constitution V).
class ChatController extends Notifier<ChatState> {
  ChatController(this.chatKey);

  final String? chatKey;

  /// How often a chat answering on another device is checked, and for how long.
  static const busyPoll = Duration(seconds: 5);
  static const busyPollFor = Duration(seconds: 60);

  /// Called when the API gives the new chat its id; the screen replaces the route.
  void Function(String chatId)? onChatCreated;

  bool _adopted = false;
  Timer? _poll;
  StreamSubscription<ChatEvent>? _answer;
  var _localIds = 0;

  @override
  ChatState build() {
    ref.onDispose(() {
      _poll?.cancel();
      unawaited(_answer?.cancel());
    });
    final id = chatKey;
    if (id == null) return const ChatState();
    // Loads after build, unless an answer moves here first.
    scheduleMicrotask(() {
      if (!_adopted && ref.mounted) unawaited(load());
    });
    return ChatState(chatId: id, status: ChatStatus.loading);
  }

  ChatRepository get _repository => ref.read(chatRepositoryProvider);

  /// Reads the chat again. A chat still answering elsewhere is checked every 5 s, for at most 60 s.
  Future<void> load() async {
    final id = state.chatId;
    if (id == null) return;
    _poll?.cancel();
    state = state.copyWith(status: ChatStatus.loading, clearFailure: true);
    try {
      final chat = await _repository.get(id);
      if (!ref.mounted) return;
      state = ChatState(
        chatId: chat.id,
        title: chat.title,
        messages: chat.messages,
        status: chat.busy ? ChatStatus.busyElsewhere : ChatStatus.idle,
      );
      if (chat.busy) _pollWhileBusy(busyPollFor.inSeconds ~/ busyPoll.inSeconds);
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(status: ChatStatus.failed, failure: _failureOf(e));
    }
  }

  void _pollWhileBusy(int checksLeft) {
    if (checksLeft <= 0) return;
    _poll = Timer(busyPoll, () async {
      if (!ref.mounted) return;
      try {
        final chat = await _repository.get(state.chatId!);
        if (!ref.mounted) return;
        if (!chat.busy) {
          state = ChatState(chatId: chat.id, title: chat.title, messages: chat.messages);
          ref.invalidate(recentsProvider);
          return;
        }
      } on Object {
        // Try again at the next tick; the screen keeps its busy state.
      }
      _pollWhileBusy(checksLeft - 1);
    });
  }

  /// Sends [text] as the traveller. It shows at once; the answer's steps come in as they run.
  Future<void> send(String text, {MessageAbout? about}) async {
    if (state.isSending || ChatRequest.textError(text) != null) return;
    final parts = ref.read(chatTripProvider.notifier).toRequestParts();
    final request = ChatRequest(
      text: text,
      trip: parts.trip,
      preferences: parts.preferences,
      pace: parts.pace,
      about: about,
    );
    final message = ChatMessage(
      id: 'local-${_localIds++}',
      role: ChatRole.traveller,
      text: request.text,
      about: about,
      at: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, message],
      pending: PendingTurn(message),
      status: ChatStatus.sending,
      clearFailure: true,
    );
    await _run(_repository.send(chatId: state.chatId, request: request));
  }

  /// Sends the last unanswered message again, as a new message.
  Future<void> retry() async {
    if (!state.canRetry) return;
    final last = state.messages.last;
    state = state.copyWith(
      messages: state.messages.sublist(0, state.messages.length - 1),
      clearPending: true,
      status: ChatStatus.idle,
      clearFailure: true,
    );
    await send(last.text, about: last.about);
  }

  Future<void> _run(Stream<ChatEvent> events) async {
    // The controller that shows the answer; it changes when a new chat gets its id.
    var target = this;
    final done = Completer<void>();
    _answer = events.listen(
      (event) {
        if (!target.ref.mounted) return;
        if (event is ChatStarted && target.state.chatId == null) {
          target = target._handOver(event);
          return;
        }
        target._apply(event);
      },
      onError: (Object error) {
        if (target.ref.mounted) target._fail(_failureOf(error));
        if (!done.isCompleted) done.complete();
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future;
    _answer = null;
  }

  /// A new chat got its id: the answer moves to that chat's controller, and this one starts empty.
  ChatController _handOver(ChatStarted started) {
    final next = ref.read(chatProvider(started.chatId).notifier)
      .._adopted = true
      ..state = _withStoredId(started).copyWith(chatId: started.chatId, title: started.title);
    state = const ChatState();
    ref.invalidate(recentsProvider);
    onChatCreated?.call(started.chatId);
    return next;
  }

  /// The state with the traveller's message under the id the API stored it with.
  ChatState _withStoredId(ChatStarted started) {
    final pending = state.pending;
    if (pending == null) return state;
    final stored = pending.message.copyWith(id: started.messageId);
    return state.copyWith(
      messages: [
        for (final m in state.messages)
          if (identical(m, pending.message)) stored else m,
      ],
      pending: PendingTurn(stored, steps: pending.steps),
    );
  }

  void _apply(ChatEvent event) {
    switch (event) {
      case ChatStarted(:final title):
        state = _withStoredId(event).copyWith(title: title);
      case StepDone(:final step):
        final pending = state.pending;
        if (pending != null) state = state.copyWith(pending: pending.withStep(step));
      case AnswerDone(:final message, :final title):
        final steps = state.pending?.steps ?? const [];
        state = state.copyWith(
          title: title,
          messages: [
            ...state.messages,
            if (message.steps.isEmpty) message.copyWith(steps: steps) else message,
          ],
          clearPending: true,
          status: ChatStatus.idle,
        );
        ref.invalidate(recentsProvider);
        final plan = message.planChanged;
        if (plan != null) ref.invalidate(planProvider(plan));
      case AnswerFailed(:final warning):
        _fail(ChatUnavailable(warning));
    }
  }

  /// Marks the message as not sent; the steps already shown stay.
  void _fail(ChatFailure failure) {
    final pending = state.pending;
    final notSent = pending?.message.copyWith(notSent: true);
    state = state.copyWith(
      messages: [
        for (final m in state.messages)
          if (identical(m, pending?.message)) notSent! else m,
      ],
      pending: notSent == null ? null : PendingTurn(notSent, steps: pending!.steps),
      status: ChatStatus.failed,
      failure: failure,
    );
  }

  static ChatFailure _failureOf(Object error) =>
      error is ChatFailure ? error : ChatUnavailable(describeApiError(error));
}

final NotifierProviderFamily<ChatController, ChatState, String?> chatProvider =
    NotifierProvider.family<ChatController, ChatState, String?>(ChatController.new, retry: noRetry);
