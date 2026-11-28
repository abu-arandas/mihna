import 'package:http/http.dart' as http;
import 'package:postgrest/postgrest.dart';

/// Neon's Data API, which speaks PostgREST, with the signed-in person's token on every request. The database checks
/// who is asking (db/migrations), so nothing here does.
class NeonData {
  NeonData({required this.url, required this.token, this.httpClient});

  /// The Data API's address, ending in `/rest/v1`.
  final String url;

  /// The signed-in person's token (NeonAuthService.accessToken).
  final Future<String?> Function() token;

  final http.Client? httpClient;

  /// A client carrying a fresh token. Throws [SignedOut] without one, which callers treat as "try again later" rather
  /// than a refusal, so the offline queue never sets a change aside only because a token ran out.
  Future<PostgrestClient> client() async {
    final jwt = await token();
    if (jwt == null) throw const SignedOut();
    return PostgrestClient(url, headers: {'Authorization': 'Bearer $jwt'}, httpClient: httpClient);
  }
}

/// Nobody is signed in, so there is no token to send.
class SignedOut implements Exception {
  const SignedOut();

  @override
  String toString() => 'Sign in first';
}
