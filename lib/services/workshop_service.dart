import 'package:postgrest/postgrest.dart';

import '../models/membership.dart';
import '../models/role.dart';
import 'change_queue.dart';
import 'neon_data.dart';

/// Workshops and the people in them. Every write is a database function that checks the caller's role
/// (db/migrations), so nothing here filters by who is asking.
abstract interface class WorkshopService {
  /// The signed-in person's workshops and their role in each.
  Future<List<Membership>> myMemberships(String userId);

  /// Everyone in [workshopId], trainees first.
  Future<List<Membership>> members(String workshopId);

  /// Starts a workshop with the caller as its admin, and returns its id.
  Future<String> startWorkshop({required String name, required String displayName});

  /// Adds someone who already has an account, or changes their role. Throws [RejectedChange] with the reason.
  Future<void> addMember({required String workshopId, required String email, required Role role, required String displayName});

  Future<void> removeMember({required String workshopId, required String userId});
}

class NeonWorkshopService implements WorkshopService {
  NeonWorkshopService(this._data);

  final NeonData _data;

  @override
  Future<List<Membership>> myMemberships(String userId) async {
    final db = await _data.client();
    final rows = await db.from('members').select('workshop_id, user_id, role, display_name').eq('user_id', userId).order('created_at');
    return _named(db, rows);
  }

  @override
  Future<List<Membership>> members(String workshopId) async {
    final db = await _data.client();
    final rows = await db.from('members').select('workshop_id, user_id, role, display_name').eq('workshop_id', workshopId).order('role').order('display_name');
    return _named(db, rows);
  }

  /// Adds each workshop's name to its members. A second plain read rather than an embedded one, which keeps to the
  /// part of PostgREST every compatible API serves.
  Future<List<Membership>> _named(PostgrestClient db, List<Map<String, dynamic>> rows) async {
    final ids = {for (final row in rows) row['workshop_id'] as String}.toList();
    final names = <String, String>{};
    if (ids.isNotEmpty) {
      for (final w in await db.from('workshops').select('id, name').inFilter('id', ids)) {
        names[w['id'] as String] = w['name'] as String;
      }
    }
    return [
      for (final row in rows) Membership.fromJson({...row, 'workshop_name': names[row['workshop_id']] ?? ''}),
    ];
  }

  @override
  Future<String> startWorkshop({required String name, required String displayName}) => rejecting(() async {
    final db = await _data.client();
    return await db.rpc<String>('start_workshop', params: {'p_name': name, 'p_display_name': displayName});
  });

  @override
  Future<void> addMember({required String workshopId, required String email, required Role role, required String displayName}) => rejecting(() async {
    final db = await _data.client();
    await db.rpc<void>('add_member', params: {'p_workshop': workshopId, 'p_email': email, 'p_role': role.name, 'p_display_name': displayName});
  });

  @override
  Future<void> removeMember({required String workshopId, required String userId}) => rejecting(() async {
    final db = await _data.client();
    await db.rpc<void>('remove_member', params: {'p_workshop': workshopId, 'p_user': userId});
  });
}

/// Runs [call], turning a refusal from the database (a raised exception, a permission or a check) into a
/// [RejectedChange] with its message. Anything else, such as no signal, passes through unchanged.
///
/// A database that has just woken can take a valid token without reading who it is for, and answers "Sign in first"
/// (seen on Neon's first request after a cold start). That is asked once more after a moment, and if it holds it is
/// left as an error to try again later, never a refusal, so the queue does not set a good change aside.
Future<T> rejecting<T>(Future<T> Function() call, {Duration retryAfter = const Duration(seconds: 1)}) async {
  try {
    try {
      return await call();
    } on PostgrestException catch (e) {
      if (!_notSignedIn(e)) rethrow;
      await Future<void>.delayed(retryAfter);
      return await call();
    }
  } on PostgrestException catch (e) {
    final code = e.code ?? '';
    // PGRST301 to PGRST303: the token was refused or ran out. Signing in again fixes that, so it is not a refusal.
    if (code.startsWith('PGRST30') || _notSignedIn(e)) rethrow;
    // P0001: raised by a function. 42501: no permission. 22xxx and 23xxx: a value or a constraint. PGRST: a request
    // the API cannot serve. All are answers from the server, not a lost connection.
    if (code == 'P0001' || code == '42501' || code.startsWith('22') || code.startsWith('23') || code.startsWith('PGRST')) {
      throw RejectedChange(e.message);
    }
    rethrow;
  }
}

bool _notSignedIn(PostgrestException e) => e.code == 'P0001' && e.message == 'Sign in first';
