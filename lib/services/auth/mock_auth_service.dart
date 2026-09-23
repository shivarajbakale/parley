import 'package:parley_android/services/auth/auth_models.dart';
import 'package:parley_android/services/auth/auth_service.dart';
import 'package:parley_android/services/auth/token_store.dart';

/// In-memory [AuthService] so the full auth flow runs without a backend.
///
/// - Seeded with a demo account: `demo@rocketship.dev` / `password`.
/// - `signUp` registers new accounts for the lifetime of the process.
/// - Sessions are persisted via the injected [TokenStore], so a cold start
///   restores the last signed-in user (the credential registry itself is
///   in-memory and resets on restart — that's fine for a mock).
///
/// Delete this once you wire a real [AuthService]; nothing else references it
/// except `ServiceConfig.createAuthService`.
class MockAuthService implements AuthService {
  final TokenStore _tokenStore;

  MockAuthService(this._tokenStore);

  // Shared across notifier rebuilds within a run.
  static final Map<String, _Account> _accounts = {
    'demo@rocketship.dev': const _Account(
      id: 'usr_demo',
      email: 'demo@rocketship.dev',
      password: 'password',
      displayName: 'Demo User',
    ),
  };

  static const _latency = Duration(milliseconds: 600);

  @override
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(_latency);
    final account = _accounts[email.trim().toLowerCase()];
    if (account == null || account.password != password) {
      throw const InvalidCredentialsException();
    }
    return _persist(account);
  }

  @override
  Future<AuthSession> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    await Future<void>.delayed(_latency);
    final key = email.trim().toLowerCase();
    if (password.length < 8) throw const WeakPasswordException();
    if (_accounts.containsKey(key)) throw const EmailInUseException();
    final account = _Account(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      email: key,
      password: password,
      displayName: displayName,
    );
    _accounts[key] = account;
    return _persist(account);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await Future<void>.delayed(_latency);
    // A real backend emails a reset link. The mock just succeeds silently so
    // the UI never leaks whether an account exists.
  }

  @override
  Future<void> completePasswordReset({
    required String token,
    required String newPassword,
  }) async {
    await Future<void>.delayed(_latency);
    if (token.isEmpty) {
      throw const AuthFailureException('Invalid or expired link.');
    }
    if (newPassword.length < 8) throw const WeakPasswordException();
    // A real backend validates the token and updates the password. The mock
    // just succeeds so the deep-link → reset-screen flow is demonstrable.
  }

  @override
  Future<void> signOut() => _tokenStore.clear();

  @override
  Future<AuthSession?> restoreSession() => _tokenStore.read();

  Future<AuthSession> _persist(_Account account) async {
    final session = AuthSession(
      user: AuthUser(
        id: account.id,
        email: account.email,
        displayName: account.displayName,
      ),
      accessToken: 'mock_access_${account.id}',
      refreshToken: 'mock_refresh_${account.id}',
    );
    await _tokenStore.write(session);
    return session;
  }
}

class _Account {
  final String id;
  final String email;
  final String password;
  final String? displayName;
  const _Account({
    required this.id,
    required this.email,
    required this.password,
    this.displayName,
  });
}
