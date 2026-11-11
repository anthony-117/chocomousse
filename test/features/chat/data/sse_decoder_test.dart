import 'dart:convert';

import 'package:chocomousse/features/chat/data/sse_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<SseEvent>> _decode(List<List<int>> chunks) =>
    Stream.fromIterable(chunks).transform(const SseDecoder()).toList();

List<int> _b(String text) => utf8.encode(text);

void main() {
  test('reads one event per chunk', () async {
    final events = await _decode([_b('event: chat\ndata: {"a":1}\n\n'), _b('event: final\ndata: {}\n\n')]);
    expect(events, const [SseEvent('chat', '{"a":1}'), SseEvent('final', '{}')]);
  });

  test('reads an event split across three chunks', () async {
    final events = await _decode([_b('eve'), _b('nt: step\nda'), _b('ta: {"ok":true}\n\n')]);
    expect(events, const [SseEvent('step', '{"ok":true}')]);
  });

  test('decodes a two-byte character split across chunks', () async {
    final bytes = _b('event: final\ndata: café\n\n');
    final cut = bytes.indexOf(0xC3) + 1;
    final events = await _decode([bytes.sublist(0, cut), bytes.sublist(cut)]);
    expect(events.single.data, 'café');
  });

  test('ignores comment lines such as : ping', () async {
    final events = await _decode([_b(': ping\n\nevent: chat\n: ping\ndata: x\n\n')]);
    expect(events, const [SseEvent('chat', 'x')]);
  });

  test(r'accepts \r\n line ends', () async {
    final events = await _decode([_b('event: chat\r\ndata: x\r\n\r\n')]);
    expect(events, const [SseEvent('chat', 'x')]);
  });

  test('joins multi-line data with a newline', () async {
    final events = await _decode([_b('event: final\ndata: one\ndata: two\n\n')]);
    expect(events.single.data, 'one\ntwo');
  });

  test('drops a trailing event with no blank line', () async {
    final events = await _decode([_b('event: chat\ndata: x\n\nevent: final\ndata: y\n')]);
    expect(events, const [SseEvent('chat', 'x')]);
  });

  test('names an event without event: "message"', () async {
    final events = await _decode([_b('data: x\n\n')]);
    expect(events.single.name, 'message');
  });
}
