import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/app/theme/appearance.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account/fakes.dart';
import '../destination/fakes.dart';
import '../helpers.dart';

/// The real app, reading Appearance as `main` does.
Future<Widget> _app() async {
  final appearance = await AppearanceController.read();
  return ProviderScope(
    overrides: [
      ...signedIn(),
      destinationRepositoryProvider.overrideWithValue(FakeDestinationRepository()),
      pingProvider.overrideWith(
        (ref) async =>
            PingInfo(name: 'pamplemousse', version: '1.0.0', environment: 'Test', utcNow: DateTime.utc(2026)),
      ),
      appearanceProvider.overrideWith(() => AppearanceController(appearance)),
    ],
    child: const TravelGenieApp(),
  );
}

void main() {
  testWidgets('Dark shows the dark palette, and a restarted app keeps it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    usePhoneSize(tester);
    await tester.pumpWidget(await tester.runAsync(_app) ?? const SizedBox());
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness, Brightness.light);

    final container = ProviderScope.containerOf(tester.element(find.byType(TravelGenieApp)));
    await tester.runAsync(() => container.read(appearanceProvider.notifier).set(ThemeMode.dark));
    await tester.pumpAndSettle();
    final theme = Theme.of(tester.element(find.byType(Scaffold).first));
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppPalette.dark.bgApp);

    // A restart: a new app reads the stored choice before its first frame.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(await tester.runAsync(_app) ?? const SizedBox());
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(Scaffold).first)).scaffoldBackgroundColor, AppPalette.dark.bgApp);
  });
}
