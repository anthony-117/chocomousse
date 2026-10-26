import 'package:chocomousse/app/theme/app_theme.dart';
import 'package:chocomousse/features/profile/presentation/profile_screen.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _card(Future<PingInfo> Function() ping) => ProviderScope(
  overrides: [pingProvider.overrideWith((ref) => ping())],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: const Scaffold(body: BackendStatusCard()),
  ),
);

void main() {
  test('PingInfo parses the API response', () {
    final info = PingInfo.fromJson({
      'name': 'pamplemousse',
      'version': '1.0.0+44c9450',
      'environment': 'Development',
      'utcNow': '2026-10-27T10:00:00+00:00',
    });

    expect(info.name, 'pamplemousse');
    expect(info.shortVersion, '1.0.0');
    expect(info.utcNow, DateTime.utc(2026, 10, 27, 10));
  });

  testWidgets('shows an error and a retry button when the backend is unreachable', (tester) async {
    await tester.pumpWidget(_card(() => Future.error(Exception('offline'))));
    await tester.pumpAndSettle();

    expect(find.textContaining('Cannot reach'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
