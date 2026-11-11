import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// One server-sent event: its `event:` name (`message` when the server gave none) and its joined `data:` lines.
@immutable
class SseEvent {
  const SseEvent(this.name, this.data);

  final String name;
  final String data;

  @override
  bool operator ==(Object other) => other is SseEvent && other.name == name && other.data == data;

  @override
  int get hashCode => Object.hash(name, data);

  @override
  String toString() => 'SseEvent($name, $data)';
}

/// Turns the bytes of a `text/event-stream` answer into [SseEvent]s (the subset of the SSE format the assistant
/// sends). UTF-8 is decoded across chunk boundaries; `\n` and `\r\n` both end a line; lines starting with `:` (the
/// server's `: ping`) are ignored; a blank line ends an event. An event the stream ends in the middle of is dropped.
class SseDecoder extends StreamTransformerBase<List<int>, SseEvent> {
  const SseDecoder();

  @override
  Stream<SseEvent> bind(Stream<List<int>> stream) async* {
    String? name;
    final data = <String>[];
    await for (final line in stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (data.isNotEmpty) yield SseEvent(name ?? 'message', data.join('\n'));
        name = null;
        data.clear();
        continue;
      }
      if (line.startsWith(':')) continue;
      final colon = line.indexOf(':');
      final field = colon < 0 ? line : line.substring(0, colon);
      var value = colon < 0 ? '' : line.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      switch (field) {
        case 'event':
          name = value;
        case 'data':
          data.add(value);
      }
    }
  }
}
