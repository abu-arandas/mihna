import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mihna/models/change.dart';
import 'package:mihna/models/role.dart';
import 'package:mihna/services/auth_service.dart';
import 'package:mihna/services/change_queue.dart';
import 'package:mihna/services/logbook_service.dart';
import 'package:mihna/services/neon_data.dart';
import 'package:mihna/services/workshop_service.dart';
import 'package:postgrest/postgrest.dart';

import 'change_queue_test.dart' show MapStore;

const auth = 'https://ep-test.neonauth.eu-central-1.aws.neon.tech/neondb/auth';
const data = 'https://ep-test.apirest.eu-central-1.aws.neon.tech/neondb/rest/v1';
const omar = 'aaaaaaaa-0000-4000-8000-000000000001';
const cookie = '__Secure-neon-auth.session_token';

/// A JWT whose payload runs out at [exp]; the signature is not checked on the phone.
String jwt(DateTime exp) {
  String part(Object json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'EdDSA'})}.${part({'sub': omar, 'role': 'authenticated', 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
}

/// Neon Auth and the Data API as far as the app uses them, recording every request.
class StandInNeon {
  final requests = <http.Request>[];
  bool signedIn = false;
  int tokens = 0;
  bool online = true;
  DateTime now = DateTime.utc(2026, 11, 28, 9);
  Map<String, Object?>? Function(http.Request request)? rpc;

  // The answer carries its request, as a real one does (the PostgREST client reads it).
  late final client = MockClient((request) async {
    final answer = await _answer(request);
    return http.Response.bytes(answer.bodyBytes, answer.statusCode, headers: answer.headers, request: request);
  });

  Future<http.Response> _answer(http.Request request) async {
    requests.add(request);
    if (!online) throw http.ClientException('no signal');
    final path = request.url.path;
    const json = {'content-type': 'application/json'};
    if (request.url.toString().startsWith(auth)) {
      if (request.headers['origin'] == null && request.method == 'POST') {
        return http.Response(jsonEncode({'code': 'MISSING_OR_NULL_ORIGIN', 'message': 'Missing or null Origin'}), 403, headers: json);
      }
      final hasCookie = request.headers['cookie']?.contains('$cookie=tok.sig') ?? false;
      switch (path.split('/auth').last) {
        case '/sign-in/email':
          final body = jsonDecode(request.body) as Map<String, Object?>;
          if (body['password'] != 'right-password') {
            return http.Response(jsonEncode({'code': 'INVALID_EMAIL_OR_PASSWORD', 'message': 'Invalid email or password'}), 401, headers: json);
          }
          signedIn = true;
          return http.Response(
            jsonEncode({
              'token': 'tok',
              'user': {'id': omar, 'email': body['email']},
            }),
            200,
            headers: {...json, 'set-cookie': '$cookie=tok.sig; Path=/; Expires=Wed, 05 Dec 2026 09:00:00 GMT; HttpOnly; Secure, other=x; Path=/'},
          );
        case '/token':
          if (!signedIn || !hasCookie) return http.Response('', 401);
          tokens++;
          return http.Response(jsonEncode({'token': jwt(now.add(const Duration(minutes: 15)))}), 200, headers: json);
        case '/get-session':
          if (!signedIn || !hasCookie) return http.Response('null', 200, headers: json);
          return http.Response(
            jsonEncode({
              'user': {'id': omar, 'email': 'omar@example.com'},
            }),
            200,
            headers: json,
          );
        case '/sign-out':
          signedIn = false;
          return http.Response('{"success":true}', 200, headers: {...json, 'set-cookie': '$cookie=; Max-Age=0; Path=/'});
        case '/forget-password/email-otp':
          return http.Response('', 404);
        case '/email-otp/send-verification-otp' || '/email-otp/reset-password':
          return http.Response('{"success":true}', 200, headers: json);
      }
      return http.Response('', 404);
    }
    if (request.headers['authorization'] == null) return http.Response('{"code":"42501","message":"permission denied"}', 401, headers: json);
    if (path.endsWith('/members')) {
      return http.Response(
        jsonEncode([
          {'workshop_id': 'w1', 'user_id': omar, 'role': 'trainee', 'display_name': 'Omar'},
        ]),
        200,
        headers: json,
      );
    }
    if (path.endsWith('/workshops')) {
      return http.Response(
        jsonEncode([
          {'id': 'w1', 'name': 'Abu Ali Auto'},
        ]),
        200,
        headers: json,
      );
    }
    if (path.contains('/rpc/')) {
      final answer = rpc?.call(request);
      if (answer != null) return http.Response(jsonEncode(answer), 400, headers: json);
      return http.Response('', 204);
    }
    return http.Response('', 404);
  }

  NeonAuthService authService(MapStore store, {String? origin = 'https://mihna.arandas.tech'}) =>
      NeonAuthService(baseUrl: auth, client: client, store: store, origin: origin, now: () => now);
}

void main() {
  test('signing in keeps the session on the phone, and the next run opens signed in', () async {
    final neon = StandInNeon();
    final store = MapStore();
    final first = neon.authService(store);
    final changes = <String?>[];
    first.userChanges.listen(changes.add);
    await first.signIn(email: ' omar@example.com ', password: 'right-password');
    expect(first.userId, omar);
    expect(neon.requests.single.headers['origin'], 'https://mihna.arandas.tech');
    expect(jsonDecode(neon.requests.single.body), {'email': 'omar@example.com', 'password': 'right-password'});
    await Future<void>.delayed(Duration.zero);
    expect(changes, [omar]);

    // A new run, with no signal: the kept session stands.
    neon.online = false;
    final second = neon.authService(store);
    await second.restore();
    await Future<void>.delayed(Duration.zero);
    expect(second.userId, omar);
    expect(second.email, 'omar@example.com');

    // With signal, the kept cookie goes back to the server.
    neon.online = true;
    final third = neon.authService(store);
    await third.restore();
    expect(await third.accessToken(), isNotNull);
    expect(neon.requests.last.headers['cookie'], contains('$cookie=tok.sig'));
    expect(neon.requests.last.headers['cookie'], contains('other=x'));
  });

  test('a wrong password is shown in the app’s own words', () async {
    final neon = StandInNeon();
    final service = neon.authService(MapStore());
    await expectLater(
      service.signIn(email: 'omar@example.com', password: 'wrong'),
      throwsA(isA<AuthFailure>().having((e) => e.message, 'message', 'Invalid login credentials')),
    );
    expect(service.userId, isNull);
  });

  test('a session the server ended signs the phone out', () async {
    final neon = StandInNeon();
    final store = MapStore();
    await neon.authService(store).signIn(email: 'omar@example.com', password: 'right-password');
    neon.signedIn = false;
    final next = neon.authService(store);
    final changes = <String?>[];
    next.userChanges.listen(changes.add);
    await next.restore();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(next.userId, isNull);
    expect(changes, [null]);
    expect(store.values, isEmpty);
  });

  test('the Data API token is reused until under a minute is left', () async {
    final neon = StandInNeon();
    final service = neon.authService(MapStore());
    await service.signIn(email: 'omar@example.com', password: 'right-password');
    final a = await service.accessToken();
    neon.now = neon.now.add(const Duration(minutes: 10));
    expect(await service.accessToken(), a);
    expect(neon.tokens, 1);
    neon.now = neon.now.add(const Duration(minutes: 4, seconds: 30));
    await service.accessToken();
    expect(neon.tokens, 2);
  });

  test('signing out forgets the session even with no signal', () async {
    final neon = StandInNeon();
    final store = MapStore();
    final service = neon.authService(store);
    await service.signIn(email: 'omar@example.com', password: 'right-password');
    neon.online = false;
    await service.signOut();
    expect(service.userId, isNull);
    expect(store.values, isEmpty);
    expect(await service.accessToken(), isNull);
  });

  test('a password reset sends a code, then sets the password and signs in', () async {
    final neon = StandInNeon();
    final service = neon.authService(MapStore());
    await service.sendPasswordReset(email: 'omar@example.com');
    final sent = neon.requests.last;
    expect(sent.url.path, endsWith('/email-otp/send-verification-otp'));
    expect(jsonDecode(sent.body), {'email': 'omar@example.com', 'type': 'forget-password'});
    await service.resetPassword(email: 'omar@example.com', code: ' 123456 ', password: 'right-password');
    final reset = neon.requests.firstWhere((r) => r.url.path.endsWith('/email-otp/reset-password'));
    expect(jsonDecode(reset.body), {'email': 'omar@example.com', 'otp': '123456', 'password': 'right-password'});
    expect(service.userId, omar);
  });

  test('the Data API gets a bearer token, and workshops come with their names', () async {
    final neon = StandInNeon();
    final service = neon.authService(MapStore());
    await service.signIn(email: 'omar@example.com', password: 'right-password');
    final workshops = NeonWorkshopService(NeonData(url: data, token: service.accessToken, httpClient: neon.client));
    final mine = await workshops.myMemberships(omar);
    expect(mine.single.workshopName, 'Abu Ali Auto');
    expect(mine.single.role, Role.trainee);
    final reads = neon.requests.where((r) => r.url.toString().startsWith(data));
    expect(reads.every((r) => r.headers['authorization']!.startsWith('Bearer ')), isTrue);
  });

  test('a refusal from the database sets a change aside; signed out or an expired token is tried again', () async {
    final neon = StandInNeon();
    final service = neon.authService(MapStore());
    final logbook = NeonLogbookService(NeonData(url: data, token: service.accessToken, httpClient: neon.client));
    final change = PractiseChange(id: 'c1', workshopId: 'w1', traineeId: omar, skillCode: 'safety.ppe', note: '', at: DateTime.utc(2026, 11, 28));
    await expectLater(logbook.send(change), throwsA(isA<SignedOut>()));

    await service.signIn(email: 'omar@example.com', password: 'right-password');
    await logbook.send(change);
    final call = neon.requests.last;
    expect(call.url.path, endsWith('/rpc/practise_skill'));
    expect((jsonDecode(call.body) as Map)['p_skill'], 'safety.ppe');

    neon.rpc = (_) => {'code': 'P0001', 'message': 'Only a trainee can log practice'};
    await expectLater(logbook.send(change), throwsA(isA<RejectedChange>().having((e) => e.message, 'message', 'Only a trainee can log practice')));
    neon.rpc = (_) => {'code': 'PGRST301', 'message': 'JWT expired'};
    await expectLater(logbook.send(change), throwsA(isNot(isA<RejectedChange>())));
  });

  test('a cold database that does not see the token yet is asked again, and never sets the change aside', () async {
    final neon = StandInNeon();
    final service = neon.authService(MapStore());
    await service.signIn(email: 'omar@example.com', password: 'right-password');
    final logbook = NeonLogbookService(NeonData(url: data, token: service.accessToken, httpClient: neon.client));
    final change = PractiseChange(id: 'c1', workshopId: 'w1', traineeId: omar, skillCode: 'safety.ppe', note: '', at: DateTime.utc(2026, 11, 28));
    var calls = 0;
    neon.rpc = (_) => ++calls == 1 ? {'code': 'P0001', 'message': 'Sign in first'} : null;
    await logbook.send(change);
    expect(calls, 2);

    neon.rpc = (_) => {'code': 'P0001', 'message': 'Sign in first'};
    await expectLater(logbook.send(change), throwsA(isA<PostgrestException>()));
  });

  test('a phone build with no origin is told plainly', () async {
    final neon = StandInNeon();
    final service = neon.authService(MapStore(), origin: null);
    await expectLater(
      service.signIn(email: 'omar@example.com', password: 'right-password'),
      throwsA(isA<AuthFailure>().having((e) => e.message, 'message', 'This app is not allowed to sign in here yet.')),
    );
  });
}
