import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/config/env.dart';
import 'package:parley_android/data/api_config.dart';

/// With no --dart-define, the boilerplate must default to a safe local dev
/// setup: dev flavor, mock backend on, localhost. (Other flavors are covered
/// by building with --dart-define=ENV=… ; they can't be exercised here because
/// these values are compile-time const.)
void main() {
  test('defaults to the dev flavor', () {
    expect(Env.flavor, AppFlavor.dev);
    expect(Env.isDev, isTrue);
    expect(Env.isProd, isFalse);
  });

  test('dev uses the mock backend and a localhost base URL', () {
    expect(Env.useMockBackend, isTrue);
    expect(Env.apiBaseUrl, contains('localhost'));
  });

  test('ApiConfig delegates to Env', () {
    expect(ApiConfig.useMockBackend, Env.useMockBackend);
    expect(ApiConfig.baseUrl, Env.apiBaseUrl);
  });
}
