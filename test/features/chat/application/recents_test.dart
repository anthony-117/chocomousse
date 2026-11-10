import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/features/chat/application/recents.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

List<Map<String, Object?>> _chats(int n) => [for (var i = 1; i <= n; i++) chatJson(id: 'c$i', title: 'Chat $i')];

ProviderContainer _container(FakeChatApi api) {
  final container = ProviderContainer(retry: noRetry, overrides: chatApiOverrides(api));
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('loads a page, then follows next until every chat is shown', () async {
    final api = FakeChatApi(chats: _chats(5), pageSize: 2);
    final c = _container(api);
    var state = await c.read(recentsProvider.future);
    expect(state.items.map((i) => i.id), ['c1', 'c2']);
    expect(state.next, '2');

    await c.read(recentsProvider.notifier).loadMore();
    await c.read(recentsProvider.notifier).loadMore();
    state = c.read(recentsProvider).requireValue;
    expect(state.items.map((i) => i.id), ['c1', 'c2', 'c3', 'c4', 'c5']);
    expect(state.next, isNull);
    expect(state.loadingMore, isFalse);
  });

  test('a page that fails leaves the list as it was', () async {
    final api = FakeChatApi(chats: _chats(3), pageSize: 2);
    final c = _container(api);
    await c.read(recentsProvider.future);
    api.failList = Exception('down');
    await expectLater(c.read(recentsProvider.notifier).loadMore(), throwsException);
    final state = c.read(recentsProvider).requireValue;
    expect(state.items, hasLength(2));
    expect((state.next, state.loadingMore), ('2', false));
  });

  test('rename and delete change the list once the API answers', () async {
    final api = FakeChatApi(chats: _chats(2));
    final c = _container(api);
    await c.read(recentsProvider.future);
    await c.read(recentsProvider.notifier).rename('c2', '  Jazz weekend ');
    expect(c.read(recentsProvider).requireValue.items.last.title, 'Jazz weekend');

    await c.read(recentsProvider.notifier).delete('c1');
    expect(c.read(recentsProvider).requireValue.items.map((i) => i.id), ['c2']);
    expect(api.chats.map((j) => j['id']), ['c2']);
  });

  test('a refused rename leaves the title', () async {
    final api = FakeChatApi(chats: _chats(1))..failRename = Exception('no');
    final c = _container(api);
    await c.read(recentsProvider.future);
    await expectLater(c.read(recentsProvider.notifier).rename('c1', 'New'), throwsException);
    expect(c.read(recentsProvider).requireValue.items.single.title, 'Chat 1');
  });

  test('search waits 300 ms after the last key, and asks only for the last query', () async {
    final api = FakeChatApi(chats: [chatJson(title: 'Jazz in Rome')]);
    final c = _container(api);
    final first = c.listen(chatSearchProvider('ja'), (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 100));
    first.close();
    final last = c.listen(chatSearchProvider('jazz'), (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(api.searches, isEmpty, reason: 'still waiting');
    final result = await c.read(chatSearchProvider('jazz').future);
    expect(result.chats.single.title, 'Jazz in Rome');
    expect(api.searches, ['jazz']);
    last.close();
  });

  test('under 2 letters it finds nothing without asking', () async {
    final api = FakeChatApi(chats: _chats(1));
    final c = _container(api);
    final result = await c.read(chatSearchProvider(' j ').future);
    expect(result.isEmpty, isTrue);
    expect(api.searches, isEmpty);
  });
}
