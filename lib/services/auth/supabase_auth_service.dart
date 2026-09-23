import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:parley_android/services/auth/auth_models.dart';
import 'package:parley_android/services/auth/auth_service.dart';

/// Real [AuthService] backed by Supabase. Activated by `ServiceConfig` when
/// `Env.hasSupabase` is true (i.e. `SUPABASE_URL` + `SUPABASE_ANON_KEY` are
/// passed via `--dart-define`). `main.dart` calls `Supabase.initialize` first.
///
/// Supabase persists its own session, so this ignores the app [TokenStore] and
/// reads `auth.currentSession` on restore.
class SupabaseAuthService implements AuthService {
  sb.GoTrueClient get _auth => sb.Supabase.instance.client.auth;

  @override
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      return _toSession(res.session, res.user);
    } on sb.AuthException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<AuthSession> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final res = await _auth.signUp(
        email: email,
        password: password,
        data: displayName == null ? null : {'display_name': displayName},
      );
      if (res.session == null) {
        // Email-confirmation is enabled on the project.
        throw const AuthFailureException(
          'Check your email to confirm your account.',
        );
      }
      return _toSession(res.session, res.user);
    } on sb.AuthException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.resetPasswordForEmail(email);
    } on sb.AuthException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> completePasswordReset({
    required String token,
    required String newPassword,
  }) async {
    // Supabase recovery deep links establish a recovery session via the SDK's
    // link handler; with that session active, update the password.
    try {
      await _auth.updateUser(sb.UserAttributes(password: newPassword));
    } on sb.AuthException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<AuthSession?> restoreSession() async {
    final session = _auth.currentSession;
    final user = _auth.currentUser;
    if (session == null || user == null) return null;
    return _toSession(session, user);
  }

  AuthSession _toSession(sb.Session? session, sb.User? user) {
    if (session == null || user == null) throw const AuthFailureException();
    return AuthSession(
      user: AuthUser(
        id: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['display_name'] as String?,
      ),
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
  }

  AuthException _map(sb.AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('already registered') ||
        m.contains('already exists') ||
        m.contains('user already')) {
      return const EmailInUseException();
    }
    if (m.contains('password') &&
        (m.contains('weak') ||
            m.contains('at least') ||
            m.contains('should be'))) {
      return const WeakPasswordException();
    }
    if (m.contains('invalid login') || m.contains('invalid credentials')) {
      return InvalidCredentialsException(e.message);
    }
    return AuthFailureException(e.message);
  }
}
