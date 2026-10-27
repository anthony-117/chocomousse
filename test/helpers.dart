import 'package:chocomousse/app/theme/app_theme.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'destination/fakes.dart';

/// Hosts one screen with the app theme and a fake repository.
Widget host(Widget screen, FakeDestinationRepository repo) => ProviderScope(
  overrides: [destinationRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: screen),
  ),
);

/// Sets a phone-sized surface (390 wide) for the current test.
void usePhoneSize(WidgetTester tester, {double height = 1400}) {
  tester.view
    ..physicalSize = Size(390, height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
