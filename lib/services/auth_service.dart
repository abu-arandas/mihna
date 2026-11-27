import 'package:supabase/supabase.dart';

/// Who is signed in, and the ways in: sign-in, sign-up and a forgotten password. Plain Dart: no GetX, no Flutter.
abstract interface class AuthService {
  /// The signed-in person's id, or null.
  String? get userId;

  /// The signed-in person's email, or null.
  String? get email;

  /// Fires whenever someone signs in or out.
  Stream<String?> get userChanges;

  /// Fires when someone opens a password-reset link. They are then signed in, and should choose a new password.
  Stream<void> get passwordRecoveries;

  /// Throws [AuthFailure] when the email and password do not match an account.
  Future<void> signIn({required String email, required String password});

  /// Creates an account. Returns true when the person is signed in at once, and false when the project asks them
  /// to confirm their email first. [redirectTo] is where the confirmation link opens (null: the project's Site URL).
  ///
  /// Throws [AuthFailure] when the project refuses the account.
  Future<bool> signUp({required String email, required String password, String? redirectTo});

  /// Emails a link that opens the app to choose a new password. It says nothing about whether the account exists.
  Future<void> sendPasswordReset({required String email, String? redirectTo});

  /// Sets the signed-in person's password, as after a reset link. Throws [AuthFailure] when it is refused.
  Future<void> updatePassword(String password);

  Future<void> signOut();
}

/// A sign-in that did not work, with a message fit to show.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Accounts in the Supabase project the build points at.
class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client);

  final SupabaseClient _client;

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  String? get email => _client.auth.currentUser?.email;

  @override
  Stream<String?> get userChanges => _client.auth.onAuthStateChange.map((state) => state.session?.user.id);

  @override
  Stream<void> get passwordRecoveries => _client.auth.onAuthStateChange.where((state) => state.event == AuthChangeEvent.passwordRecovery).map((_) {});

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(() => _client.auth.signInWithPassword(email: email.trim(), password: password));

  @override
  Future<bool> signUp({required String email, required String password, String? redirectTo}) => _guard(() async {
    final response = await _client.auth.signUp(email: email.trim(), password: password, emailRedirectTo: redirectTo);
    // With email confirmation on, an email that already has an account gets the same answer as a new one (no
    // session), so the screen cannot be used to learn who has an account.
    return response.session != null;
  });

  @override
  Future<void> sendPasswordReset({required String email, String? redirectTo}) =>
      _guard(() => _client.auth.resetPasswordForEmail(email.trim(), redirectTo: redirectTo));

  @override
  Future<void> updatePassword(String password) => _guard(() => _client.auth.updateUser(UserAttributes(password: password)));

  @override
  Future<void> signOut() => _client.auth.signOut();

  /// Runs [call], turning Supabase's refusal into an [AuthFailure] with its message.
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }
}
