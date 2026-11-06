import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Every environment value the app reads, in one place.
///
/// Values come from `assets/env/app.env` (git-ignored; copy `assets/env/app.env.example`), loaded once by [Env.load]
/// before the app starts. Missing or blank values fall back to the defaults below.
/// The file ships inside the app, so it must never contain secrets.
abstract final class Env {
  static const assetPath = 'assets/env/app.env';

  /// pamplemousse API (without /api/v1). Android emulator: http://10.0.2.2:5064.
  static String get apiBaseUrl => get('API_BASE_URL', 'http://localhost:5064');

  /// Passport used for visa checks until the traveller picks one (ISO 3166 alpha-2).
  static String get defaultPassport => get('DEFAULT_PASSPORT', 'LB');

  /// Currency prices are converted from until the traveller picks one (ISO 4217).
  static String get defaultCurrency => get('DEFAULT_CURRENCY', 'USD');

  // Firebase sign-in (ADR 0020). Public app settings from the Firebase console (Project settings → Your apps), not
  // secrets (constitution 1.1.0). Any blank value turns sign-in off, and Welcome names the missing setting.
  static String get firebaseProjectId => get('FIREBASE_PROJECT_ID', '');
  static String get firebaseAuthDomain => get('FIREBASE_AUTH_DOMAIN', '');
  static String get firebaseMessagingSenderId => get('FIREBASE_MESSAGING_SENDER_ID', '');
  static String get firebaseWebAppId => get('FIREBASE_WEB_APP_ID', '');
  static String get firebaseWebApiKey => get('FIREBASE_WEB_API_KEY', '');
  static String get firebaseAndroidAppId => get('FIREBASE_ANDROID_APP_ID', '');
  static String get firebaseAndroidApiKey => get('FIREBASE_ANDROID_API_KEY', '');

  static final Map<String, String> _values = {};

  /// Returns the value of [name] when it is set and not blank, otherwise [defaultValue].
  static String get(String name, String defaultValue) {
    final value = _values[name];
    return value == null || value.trim().isEmpty ? defaultValue : value;
  }

  /// Loads [assetPath]; when the file is missing every value keeps its default.
  static Future<void> load({AssetBundle? bundle}) async {
    try {
      parse(await (bundle ?? rootBundle).loadString(assetPath));
    } on Object {
      // No app.env bundled (each platform reports a missing asset differently, some as Error): defaults apply.
    }
  }

  /// Reads KEY=VALUE lines; blank lines and # comments are ignored, surrounding quotes removed.
  @visibleForTesting
  static void parse(String content) {
    for (final raw in content.split('\n')) {
      final line = raw.trim();
      final separator = line.indexOf('=');
      if (line.isEmpty || line.startsWith('#') || separator <= 0) continue;

      final key = line.substring(0, separator).trim();
      var value = line.substring(separator + 1).trim();
      if (value.length >= 2 && (value[0] == '"' || value[0] == "'") && value[value.length - 1] == value[0]) {
        value = value.substring(1, value.length - 1);
      }
      _values[key] = value;
    }
  }

  @visibleForTesting
  static void reset() => _values.clear();
}
