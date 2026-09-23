/// Authenticated user. Keep this minimal and backend-agnostic — map your
/// provider's user object (Supabase `User`, Firebase `User`, your own JWT
/// claims) into this shape inside the concrete [AuthService].
class AuthUser {
  final String id;
  final String email;
  final String? displayName;

  const AuthUser({required this.id, required this.email, this.displayName});

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
  };
}

/// A persisted session: the user plus whatever tokens the backend issued.
/// The [TokenStore] serializes this to secure storage so the session
/// survives app restarts.
class AuthSession {
  final AuthUser user;
  final String accessToken;
  final String? refreshToken;

  const AuthSession({
    required this.user,
    required this.accessToken,
    this.refreshToken,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'user': user.toJson(),
    'accessToken': accessToken,
    'refreshToken': refreshToken,
  };
}

/// Typed auth failures so the UI can show the right message without parsing
/// strings. Concrete [AuthService]s map their backend errors onto these.
sealed class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => '$runtimeType: $message';
}

/// Wrong email/password, or no such account.
class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException([
    super.message = 'Incorrect email or password.',
  ]);
}

/// Sign-up attempted with an email that already exists.
class EmailInUseException extends AuthException {
  const EmailInUseException([
    super.message = 'That email is already registered.',
  ]);
}

/// Password failed the backend's strength rules.
class WeakPasswordException extends AuthException {
  const WeakPasswordException([
    super.message = 'Password must be at least 8 characters.',
  ]);
}

/// Network / unexpected backend failure.
class AuthFailureException extends AuthException {
  const AuthFailureException([
    super.message = 'Something went wrong. Please try again.',
  ]);
}
