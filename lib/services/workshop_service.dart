import 'package:supabase/supabase.dart';

import '../models/membership.dart';
import '../models/role.dart';
import 'change_queue.dart';

/// Workshops and the people in them. Every write is a database function that checks the caller's role
/// (supabase/migrations), so nothing here filters by who is asking.
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

class SupabaseWorkshopService implements WorkshopService {
  SupabaseWorkshopService(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Membership>> myMemberships(String userId) async {
    final rows = await _client.from('members').select('workshop_id, user_id, role, display_name, workshops(name)').eq('user_id', userId).order('created_at');
    return [for (final row in rows) Membership.fromJson(row)];
  }

  @override
  Future<List<Membership>> members(String workshopId) async {
    final rows = await _client
        .from('members')
        .select('workshop_id, user_id, role, display_name, workshops(name)')
        .eq('workshop_id', workshopId)
        .order('role')
        .order('display_name');
    return [for (final row in rows) Membership.fromJson(row)];
  }

  @override
  Future<String> startWorkshop({required String name, required String displayName}) =>
      rejecting(() async => await _client.rpc<String>('start_workshop', params: {'p_name': name, 'p_display_name': displayName}));

  @override
  Future<void> addMember({required String workshopId, required String email, required Role role, required String displayName}) => rejecting(
    () => _client.rpc<void>('add_member', params: {'p_workshop': workshopId, 'p_email': email, 'p_role': role.name, 'p_display_name': displayName}),
  );

  @override
  Future<void> removeMember({required String workshopId, required String userId}) =>
      rejecting(() => _client.rpc<void>('remove_member', params: {'p_workshop': workshopId, 'p_user': userId}));
}

/// Runs [call], turning a refusal from the database (a raised exception, a permission or a check) into a
/// [RejectedChange] with its message. Anything else, such as no signal, passes through unchanged.
Future<T> rejecting<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on PostgrestException catch (e) {
    final code = e.code ?? '';
    // P0001: raised by a function. 42501: no permission. 22xxx and 23xxx: a value or a constraint. PGRST: a request
    // the API cannot serve. All are answers from the server, not a lost connection.
    if (code == 'P0001' || code == '42501' || code.startsWith('22') || code.startsWith('23') || code.startsWith('PGRST')) {
      throw RejectedChange(e.message);
    }
    rethrow;
  }
}
