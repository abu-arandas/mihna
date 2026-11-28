import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'local_store.dart';

/// Who is signed in, and the ways in: sign-in, sign-up and a forgotten password. Plain Dart: no GetX, no Flutter.
abstract interface class AuthService {
  /// The signed-in person's id, or null.
  String? get userId;

  /// The signed-in person's email, or null.
  String? get email;

  /// Fires whenever someone signs in or out.
  Stream<String?> get userChanges;

  /// Throws [AuthFailure] when the email and password do not match an account.
  Future<void> signIn({required String email, required String password});

  /// Creates an account. Returns true when the person is signed in at once, and false when the project asks them
  /// to confirm their email first.
  ///
  /// Throws [AuthFailure] when the project refuses the account.
  Future<bool> signUp({required String email, required String password});

  /// Emails a code for choosing a new password. It says nothing about whether the account exists.
  Future<void> sendPasswordReset({required String email});

  /// Sets a new password with the emailed [code], then signs in with it. Throws [AuthFailure] when it is refused.
  Future<void> resetPassword({required String email, required String code, required String password});

  Future<void> signOut();
}

/// A sign-in that did not work, with a message fit to show.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Accounts in Neon Auth (Neon's managed Better Auth), over its HTTP API, plus the short-lived token the Data API
/// takes ([accessToken]).
///
/// The session is a cookie. On a phone the app keeps it itself, with who is signed in, in [LocalStore], so the app
/// opens signed in with no signal; on the web the browser keeps it. A phone sends [origin] as its `Origin` header,
/// which must be one of the project's trusted domains (docs/SETUP.md); a browser sends its own.
class NeonAuthService implements AuthService {
  NeonAuthService({required String baseUrl, required this._client, required this._store, this.origin, DateTime Function()? now})
    : _base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
      _now = now ?? DateTime.now;

  final String _base;
  final http.Client _client;
  final LocalStore _store;
  final DateTime Function() _now;

  /// The `Origin` header a phone sends; null on the web, where the browser sets it.
  final String? origin;

  static const _key = 'mihna.auth';

  final _changes = StreamController<String?>.broadcast();
  final _cookies = <String, String>{};
  String? _userId;
  String? _email;
  String? _jwt;
  DateTime? _jwtExpires;
  Future<String?>? _refreshing;

  @override
  String? get userId => _userId;

  @override
  String? get email => _email;

  @override
  Stream<String?> get userChanges => _changes.stream;

  /// Opens the last session kept on the phone, then asks the server whether it still holds. With no signal the kept
  /// session stands, so the logbook works offline; a session the server has ended signs the person out.
  Future<void> restore() async {
    final saved = await _store.read(_key);
    if (saved != null) {
      try {
        final json = jsonDecode(saved) as Map<String, Object?>;
        _userId = json['user_id'] as String?;
        _email = json['email'] as String?;
        _cookies.addAll((json['cookies'] as Map<String, Object?>? ?? {}).map((k, v) => MapEntry(k, v! as String)));
      } on Object {
        await _store.remove(_key);
      }
    }
    unawaited(_check());
  }

  Future<void> _check() async {
    try {
      final response = await _send('GET', '/get-session');
      if (response.statusCode != 200) return;
      final body = response.body.trim();
      final user = body.isEmpty || body == 'null' ? null : (jsonDecode(body) as Map<String, Object?>?)?['user'] as Map<String, Object?>?;
      if (user == null) {
        if (_userId != null) await _forget();
      } else {
        await _keep(user);
      }
    } on Object {
      // No signal: keep what the phone has.
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    final json = await _post('/sign-in/email', {'email': email.trim(), 'password': password});
    await _keep(json['user'] as Map<String, Object?>?);
  }

  @override
  Future<bool> signUp({required String email, required String password}) async {
    final address = email.trim();
    final json = await _post('/sign-up/email', {'email': address, 'password': password, 'name': address.split('@').first});
    // With email verification on there is no session yet (no token), and the person confirms their email first.
    if (json['token'] == null) return false;
    await _keep(json['user'] as Map<String, Object?>?);
    return true;
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    final body = {'email': email.trim()};
    try {
      await _post('/forget-password/email-otp', body);
    } on _NotFound {
      await _post('/email-otp/send-verification-otp', {...body, 'type': 'forget-password'});
    }
  }

  @override
  Future<void> resetPassword({required String email, required String code, required String password}) async {
    await _post('/email-otp/reset-password', {'email': email.trim(), 'otp': code.trim(), 'password': password});
    await signIn(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    try {
      await _send('POST', '/sign-out', body: <String, Object?>{});
    } on Object {
      // Signed out on the phone either way; the server's session ends on its own.
    }
    await _forget();
  }

  /// A token for the Data API, fetched again when the one held has under a minute left. Null when nobody is signed
  /// in or the server has ended the session. Throws when there is no signal.
  Future<String?> accessToken() {
    final expires = _jwtExpires;
    if (_jwt != null && expires != null && expires.isAfter(_now().add(const Duration(minutes: 1)))) return Future.value(_jwt);
    if (_userId == null) return Future.value();
    return _refreshing ??= _fetchToken().whenComplete(() => _refreshing = null);
  }

  Future<String?> _fetchToken() async {
    final response = await _send('GET', '/token');
    if (response.statusCode == 401) {
      await _forget();
      return null;
    }
    String? token;
    if (response.statusCode == 200) {
      token = (jsonDecode(response.body) as Map<String, Object?>)['token'] as String?;
    }
    if (token == null) {
      final session = await _send('GET', '/get-session');
      token = session.headers['set-auth-jwt'];
    }
    if (token == null) throw http.ClientException('No token from Neon Auth (${response.statusCode})');
    _jwt = token;
    _jwtExpires = expiryOf(token) ?? _now().add(const Duration(minutes: 10));
    return token;
  }

  /// When a JWT runs out, from its `exp` claim.
  static DateTime? expiryOf(String jwt) {
    try {
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(jwt.split('.')[1])))) as Map<String, Object?>;
      final exp = payload['exp'] as num?;
      return exp == null ? null : DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
    } on Object {
      return null;
    }
  }

  Future<void> _keep(Map<String, Object?>? user) async {
    final id = user?['id'] as String?;
    if (id == null) throw const AuthFailure('Something went wrong. Try again.');
    final changed = id != _userId;
    _userId = id;
    _email = user?['email'] as String?;
    if (changed) {
      _jwt = null;
      _jwtExpires = null;
    }
    await _save();
    if (changed) _changes.add(id);
  }

  Future<void> _forget() async {
    final had = _userId != null;
    _userId = null;
    _email = null;
    _jwt = null;
    _jwtExpires = null;
    _cookies.clear();
    await _store.remove(_key);
    if (had) _changes.add(null);
  }

  Future<void> _save() => _store.write(_key, jsonEncode({'user_id': _userId, 'email': _email, 'cookies': _cookies}));

  /// POSTs [body], returning the answer's JSON, or throwing [AuthFailure] with a message fit to show.
  Future<Map<String, Object?>> _post(String path, Map<String, Object?> body) async {
    final response = await _send('POST', path, body: body);
    final text = response.body.trim();
    Object? json;
    try {
      json = text.isEmpty ? null : jsonDecode(text);
    } on FormatException {
      json = null;
    }
    final map = json is Map<String, Object?> ? json : <String, Object?>{};
    if (response.statusCode == 404) throw const _NotFound();
    if (response.statusCode >= 400) throw AuthFailure(failureMessage(response.statusCode, map['code'] as String?, map['message'] as String?));
    return map;
  }

  /// The app's own text for one of Neon Auth's refusals (each has Arabic in lib/l10n), or its message as it came.
  static String failureMessage(int status, String? code, String? message) => switch (code) {
    'INVALID_EMAIL_OR_PASSWORD' || 'INVALID_PASSWORD' || 'USER_NOT_FOUND' => 'Invalid login credentials',
    'USER_ALREADY_EXISTS' || 'USER_ALREADY_EXISTS_USE_ANOTHER_EMAIL' => 'User already registered',
    'EMAIL_NOT_VERIFIED' => 'Email not confirmed',
    'INVALID_EMAIL' => 'Enter a valid email',
    'PASSWORD_TOO_SHORT' => 'That password is too short',
    'INVALID_OTP' || 'OTP_EXPIRED' || 'INVALID_TOKEN' => 'That code is wrong or has run out. Ask for a new one.',
    'TOO_MANY_ATTEMPTS' => 'Too many tries. Ask for a new code.',
    'MISSING_OR_NULL_ORIGIN' || 'MISSING_ORIGIN' || 'INVALID_ORIGIN' => 'This app is not allowed to sign in here yet.',
    _ when status == 429 => 'Too many tries. Wait a little and try again.',
    _ => message == null || message.isEmpty ? 'Something went wrong. Try again.' : message,
  };

  Future<http.Response> _send(String method, String path, {Map<String, Object?>? body}) async {
    final request = http.Request(method, Uri.parse('$_base$path'));
    if (body != null) {
      request
        ..headers['content-type'] = 'application/json'
        ..body = jsonEncode(body);
    }
    if (origin != null) request.headers['origin'] = origin!;
    if (_cookies.isNotEmpty) request.headers['cookie'] = [for (final e in _cookies.entries) '${e.key}=${e.value}'].join('; ');
    final response = await http.Response.fromStream(await _client.send(request)).timeout(const Duration(seconds: 30));
    if (_takeCookies(response.headers['set-cookie']) && _userId != null) await _save();
    return response;
  }

  /// Keeps the cookies a phone was given (a browser never shows them). Returns whether any changed.
  bool _takeCookies(String? header) {
    if (header == null || header.isEmpty) return false;
    var changed = false;
    // Several Set-Cookie headers arrive joined by commas; an Expires date has a comma too, but no `name=` after it.
    for (final cookie in header.split(RegExp(r',(?=\s*[^;,=\s]+=)'))) {
      final parts = cookie.split(';');
      final eq = parts.first.indexOf('=');
      if (eq <= 0) continue;
      final name = parts.first.substring(0, eq).trim();
      final value = parts.first.substring(eq + 1).trim();
      final gone = value.isEmpty || parts.any((p) => p.trim().toLowerCase() == 'max-age=0');
      if (gone) {
        changed = _cookies.remove(name) != null || changed;
      } else if (_cookies[name] != value) {
        _cookies[name] = value;
        changed = true;
      }
    }
    return changed;
  }
}

class _NotFound implements Exception {
  const _NotFound();
}
