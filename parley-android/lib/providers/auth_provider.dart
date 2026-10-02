import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parley_android/providers/observability_provider.dart';
import 'package:parley_android/services/auth/auth_models.dart';
import 'package:parley_android/services/auth/auth_service.dart';
import 'package:parley_android/services/auth/token_store.dart';
import 'package:parley_android/services/service_config.dart';

/// Where the session is persisted. Tests override this with
/// [InMemoryTokenStore] to avoid the secure-storage platform channel (and to
/// seed an authenticated session).
final tokenStoreProvider = Provider<TokenStore>((ref) {
  return ServiceConfig.createTokenStore();
});

/// The active [AuthService] implementation.
final authServiceProvider = Provider<AuthService>((ref) {
  return ServiceConfig.createAuthService(ref.watch(tokenStoreProvider));
});

enum AuthStatus {
  /// Boot: we haven't checked persisted storage yet. Show a splash.
  unknown,
  authenticated,
  unauthenticated,
}

class AuthState {
  final AuthStatus status;
  final AuthSession? session;

  /// True while a sign-in / sign-up / reset request is in flight.
  final bool submitting;

  /// Last user-facing error message, or null.
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.session,
    this.submitting = false,
    this.error,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  AuthService get _service => _ref.read(authServiceProvider);

  AuthNotifier(this._ref) : super(const AuthState()) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final session = await _service.restoreSession();
      _emitSession(session);
    } catch (error, stack) {
      _ref.read(crashReporterProvider).recordError(error, stack);
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> signIn({required String email, required String password}) {
    return _run(
      () => _service.signInWithPassword(email: email, password: password),
      event: 'sign_in',
    );
  }

  Future<bool> signUp({
    required String email,
    required String password,
    String? displayName,
  }) {
    return _run(
      () => _service.signUp(
        email: email,
        password: password,
        displayName: displayName,
      ),
      event: 'sign_up',
    );
  }

  /// Sends a reset email. Returns true on success; sets [AuthState.error] on
  /// failure. Does not change auth status.
  Future<bool> sendPasswordReset(String email) async {
    state = AuthState(
      status: state.status,
      session: state.session,
      submitting: true,
    );
    try {
      await _service.sendPasswordReset(email);
      state = AuthState(status: state.status, session: state.session);
      return true;
    } on AuthException catch (e) {
      state = AuthState(
        status: state.status,
        session: state.session,
        error: e.message,
      );
      return false;
    }
  }

  /// Completes a reset from a `/reset?token=…` deep link. Returns true on
  /// success; sets [AuthState.error] otherwise. Does not change auth status.
  Future<bool> completePasswordReset({
    required String token,
    required String newPassword,
  }) async {
    state = AuthState(
      status: state.status,
      session: state.session,
      submitting: true,
    );
    try {
      await _service.completePasswordReset(
        token: token,
        newPassword: newPassword,
      );
      state = AuthState(status: state.status, session: state.session);
      return true;
    } on AuthException catch (e) {
      state = AuthState(
        status: state.status,
        session: state.session,
        error: e.message,
      );
      return false;
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    _ref.read(analyticsProvider).event('sign_out');
    _ref.read(analyticsProvider).reset();
    _ref.read(crashReporterProvider).setUser(null);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Clears the inline error (e.g. when the user edits a field).
  void clearError() {
    if (state.error == null) return;
    state = AuthState(status: state.status, session: state.session);
  }

  Future<bool> _run(
    Future<AuthSession> Function() action, {
    required String event,
  }) async {
    state = AuthState(
      status: state.status,
      session: state.session,
      submitting: true,
    );
    try {
      final session = await action();
      _emitSession(session, event: event);
      return true;
    } on AuthException catch (e) {
      state = AuthState(status: AuthStatus.unauthenticated, error: e.message);
      return false;
    } catch (error, stack) {
      _ref.read(crashReporterProvider).recordError(error, stack);
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        error: 'Something went wrong. Please try again.',
      );
      return false;
    }
  }

  void _emitSession(AuthSession? session, {String? event}) {
    if (session == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    final analytics = _ref.read(analyticsProvider);
    analytics.identify(session.user.id, traits: {'email': session.user.email});
    if (event != null) analytics.event(event);
    _ref.read(crashReporterProvider).setUser(session.user.id);
    state = AuthState(status: AuthStatus.authenticated, session: session);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

/// Convenience: the signed-in user, or null.
final currentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authProvider).session?.user;
});
