import 'package:chocomousse/app/theme/appearance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ThemeMode> _loaded(Map<String, Object> stored) async {
  SharedPreferences.setMockInitialValues(stored);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.listen(appearanceProvider, (_, _) {});
  await Future<void>.delayed(Duration.zero);
  final mode = container.read(appearanceProvider);
  return mode;
}

void main() {
  test('is System when nothing is stored', () async {
    expect(await _loaded({}), ThemeMode.system);
  });

  test('reads each stored value', () async {
    expect(await _loaded({'appearance': 'light'}), ThemeMode.light);
    expect(await _loaded({'appearance': 'dark'}), ThemeMode.dark);
    expect(await _loaded({'appearance': 'system'}), ThemeMode.system);
  });

  test('an unknown value is System', () async {
    expect(await _loaded({'appearance': 'sepia'}), ThemeMode.system);
  });

  test('set shows the choice at once and stores it', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(appearanceProvider.notifier).set(ThemeMode.dark);
    expect(container.read(appearanceProvider), ThemeMode.dark);
    expect((await SharedPreferences.getInstance()).getString('appearance'), 'dark');
    expect(await AppearanceController.read(), ThemeMode.dark);
  });

  test('a choice made while the stored value loads is kept', () async {
    SharedPreferences.setMockInitialValues({'appearance': 'light'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(appearanceProvider, (_, _) {});
    await container.read(appearanceProvider.notifier).set(ThemeMode.dark);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(appearanceProvider), ThemeMode.dark);
  });

  test('an initial value from main is used without reading', () {
    final container = ProviderContainer(
      overrides: [appearanceProvider.overrideWith(() => AppearanceController(ThemeMode.dark))],
    );
    addTearDown(container.dispose);
    expect(container.read(appearanceProvider), ThemeMode.dark);
  });
}
