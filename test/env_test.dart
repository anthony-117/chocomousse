import 'package:chocomousse/env.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fails like Flutter web does when an asset is not bundled (not a FlutterError).
class _MissingAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => Future.error(Exception('HTTP 404 for $key'));
}

void main() {
  tearDown(Env.reset);

  test('get returns the default when a value is missing or blank', () {
    Env.parse('BLANK=   ');

    expect(Env.get('MISSING', 'fallback'), 'fallback');
    expect(Env.get('BLANK', 'fallback'), 'fallback');
    expect(Env.apiBaseUrl, 'http://localhost:5064');
  });

  test('load keeps defaults when app.env is missing', () async {
    await Env.load(bundle: _MissingAssetBundle());

    expect(Env.apiBaseUrl, 'http://localhost:5064');
  });

  test('parse reads values, strips quotes and skips comments', () {
    Env.parse('''
# comment
API_BASE_URL=https://api.example.com
DEFAULT_PASSPORT="FR"
not a pair
''');

    expect(Env.apiBaseUrl, 'https://api.example.com');
    expect(Env.defaultPassport, 'FR');
    expect(Env.defaultCurrency, 'USD');
  });
}
