import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:parley_android/services/auth/auth_models.dart';

/// Persists the [AuthSession] across app restarts.
///
/// Tokens must NOT live in `SharedPreferences` (it is unencrypted). The
/// default [SecureTokenStore] uses the platform keychain / keystore.
/// Tests override the provider with [InMemoryTokenStore] to avoid the
/// platform channel.
abstract interface class TokenStore {
  Future<void> write(AuthSession session);
  Future<AuthSession?> read();
  Future<void> clear();
}

/// Default: encrypted, OS-backed storage (`flutter_secure_storage`).
class SecureTokenStore implements TokenStore {
  static const _key = 'auth_session';
  final FlutterSecureStorage _storage;

  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<void> write(AuthSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  @override
  Future<AuthSession?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt / schema-changed payload — treat as signed out.
      await clear();
      return null;
    }
  }

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// In-memory store with no platform dependency. Use in tests and previews.
class InMemoryTokenStore implements TokenStore {
  AuthSession? _session;

  InMemoryTokenStore([this._session]);

  @override
  Future<void> write(AuthSession session) async => _session = session;

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> clear() async => _session = null;
}
