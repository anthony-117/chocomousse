import 'package:chocomousse/core/network/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a failed request is reported at once and tried only once', () async {
    var calls = 0;
    final failing = FutureProvider<int>((ref) async {
      calls++;
      throw Exception('server down');
    });
    final container = ProviderContainer(retry: noRetry);
    addTearDown(container.dispose);

    final subscription = container.listen(failing, (_, _) {});
    addTearDown(subscription.close);
    await expectLater(container.read(failing.future), throwsException);
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(calls, 1);
    expect(container.read(failing).hasError, isTrue);
  });
}
