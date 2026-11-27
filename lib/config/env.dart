/// What the build was given with `--dart-define`: the Supabase project the records live in, and where errors go.
///
/// Every build runs on a real project: there is no demo mode and no sample data. A build without the keys shows
/// why it cannot start instead of the app (see [problem]).
class Env {
  const Env({required this.supabaseUrl, required this.supabaseKey, required this.authRedirect});

  /// This build's values.
  static const current = Env(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    authRedirect: String.fromEnvironment('AUTH_REDIRECT_URL'),
  );

  /// `--dart-define=SENTRY_DSN=<a Sentry project's DSN>` sends every uncaught error to that project
  /// (docs/DEPLOY.md, "Error reports"). Optional: empty, nothing is sent anywhere.
  static const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// The commit the build was made from, given as `SENTRY_RELEASE`, so a report says which deploy it came from.
  static const sentryRelease = String.fromEnvironment('SENTRY_RELEASE');

  final String supabaseUrl;

  /// The project's publishable (anon) key. The service-role key never goes in an app.
  final String supabaseKey;

  /// Where the links in sign-up and password-reset emails open, from the optional `AUTH_REDIRECT_URL`. Empty means
  /// the project's Site URL. It must be listed under Authentication → URL Configuration (docs/SETUP.md).
  final String authRedirect;

  /// [authRedirect], or null when the build was given none.
  String? get authRedirectUrl => authRedirect.trim().isEmpty ? null : authRedirect.trim();

  /// Why the keys cannot be right, or null when they can.
  String? get problem {
    if (supabaseUrl.trim().isEmpty || supabaseKey.trim().isEmpty) {
      return 'This build has no Supabase project. Build it with --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=... (docs/SETUP.md).';
    }
    final address = Uri.tryParse(supabaseUrl.trim());
    if (address == null || address.scheme != 'https' || address.host.isEmpty) {
      return 'SUPABASE_URL must be the https address of the Supabase project.';
    }
    if (supabaseKey.trim().length < 20) return "SUPABASE_ANON_KEY must be the project's publishable (anon) key.";
    return null;
  }
}
