import 'package:parley_android/services/auth/auth_models.dart';

/// Authentication seam.
///
/// The boilerplate ships [MockAuthService] (in `mock_auth_service.dart`) so
/// the full sign-in / sign-up / gated-routing flow runs with zero backend.
/// To go live, implement this interface against your provider and return it
/// from `ServiceConfig.createAuthService()`:
///
/// - **Supabase:** wrap `supabase.auth.signInWithPassword(...)`.
/// - **Firebase:** wrap `FirebaseAuth.instance.signInWithEmailAndPassword(...)`.
/// - **Your own backend:** POST to `/auth/login` via the existing `dioCall`
///   helper and persist the returned JWT.
///
/// Implementations MUST throw an [AuthException] subtype on failure and MUST
/// persist the session via the injected [TokenStore] so [restoreSession]
/// works after a cold start.
abstract interface class AuthService {
  /// Signs in with email + password. Throws [InvalidCredentialsException] on
  /// bad credentials, [AuthFailureException] on anything else.
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  });

  /// Registers a new account. Throws [EmailInUseException] or
  /// [WeakPasswordException] as appropriate.
  Future<AuthSession> signUp({
    required String email,
    required String password,
    String? displayName,
  });

  /// Sends a password-reset email. Never reveals whether the email exists.
  Future<void> sendPasswordReset(String email);

  /// Completes a password reset using the token from a deep link
  /// (`/reset?token=…`). Throws [WeakPasswordException] or
  /// [AuthFailureException] (e.g. invalid/expired token).
  Future<void> completePasswordReset({
    required String token,
    required String newPassword,
  });

  /// Clears the persisted session and signs the user out.
  Future<void> signOut();

  /// Returns the persisted session on cold start, or null if signed out.
  Future<AuthSession?> restoreSession();
}
