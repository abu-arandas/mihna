import 'brand.dart';

/// What the build was given with `--dart-define`: the Neon project the records live in, and where errors go.
///
/// Every build runs on a real project: there is no demo mode and no sample data. A build without the addresses shows
/// why it cannot start instead of the app (see [problem]).
class Env {
  const Env({required this.authUrl, required this.dataUrl, required this.appOrigin});

  /// This build's values.
  static const current = Env(
    authUrl: String.fromEnvironment('NEON_AUTH_URL'),
    dataUrl: String.fromEnvironment('NEON_DATA_API_URL'),
    appOrigin: String.fromEnvironment('APP_ORIGIN', defaultValue: Brand.appOrigin),
  );

  /// `--dart-define=SENTRY_DSN=<a Sentry project's DSN>` sends every uncaught error to that project
  /// (docs/DEPLOY.md, "Error reports"). Optional: empty, nothing is sent anywhere.
  static const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// The commit the build was made from, given as `SENTRY_RELEASE`, so a report says which deploy it came from.
  static const sentryRelease = String.fromEnvironment('SENTRY_RELEASE');

  /// Neon Auth's address (Console → Auth → Configuration), ending in `/auth`. Neither it nor [dataUrl] is a secret:
  /// the database decides what each signed-in person may read and do.
  final String authUrl;

  /// The Data API's address (Console → Data API), ending in `/rest/v1`.
  final String dataUrl;

  /// The `Origin` a phone build sends to Neon Auth. It must be one of the project's trusted domains (docs/SETUP.md).
  final String appOrigin;

  /// Why the addresses cannot be right, or null when they can.
  String? get problem {
    if (authUrl.trim().isEmpty || dataUrl.trim().isEmpty) {
      return 'This build has no Neon project. Build it with --dart-define=NEON_AUTH_URL=... and --dart-define=NEON_DATA_API_URL=... (docs/SETUP.md).';
    }
    for (final (name, value) in [('NEON_AUTH_URL', authUrl), ('NEON_DATA_API_URL', dataUrl), ('APP_ORIGIN', appOrigin)]) {
      final address = Uri.tryParse(value.trim());
      // Only the origin may be http, for a localhost build while the project still allows localhost.
      final schemes = name == 'APP_ORIGIN' ? const ['https', 'http'] : const ['https'];
      if (address == null || !schemes.contains(address.scheme) || address.host.isEmpty) return '$name must be an https address.';
    }
    return null;
  }
}
