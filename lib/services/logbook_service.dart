import 'package:supabase/supabase.dart';

import '../models/change.dart';
import '../models/skill_record.dart';
import 'workshop_service.dart';

/// The skill records of a workshop, and sending the changes the phone queued (lib/services/change_queue.dart).
abstract interface class LogbookService {
  /// The records the caller may see in [workshopId]: their own for a trainee, everyone's for a supervisor.
  Future<List<SkillRecord>> records(String workshopId);

  /// Sends one queued change. Safe to call again with the same change. Throws RejectedChange when the server
  /// refuses it for good; any other error means try again later.
  Future<void> send(Change change);
}

class SupabaseLogbookService implements LogbookService {
  SupabaseLogbookService(this._client);

  final SupabaseClient _client;

  @override
  Future<List<SkillRecord>> records(String workshopId) async {
    final rows = await _client.from('skill_records').select().eq('workshop_id', workshopId).order('updated_at');
    return [for (final row in rows) SkillRecord.fromJson(row)];
  }

  @override
  Future<void> send(Change change) => rejecting(
    () => switch (change) {
      PractiseChange() => _client.rpc<void>(
        'practise_skill',
        params: {'p_workshop': change.workshopId, 'p_skill': change.skillCode, 'p_note': change.note, 'p_at': change.at.toUtc().toIso8601String()},
      ),
      ReviewChange() => _client.rpc<void>(
        'review_skill',
        params: {
          'p_workshop': change.workshopId,
          'p_trainee': change.traineeId,
          'p_skill': change.skillCode,
          'p_decision': change.signedOff ? 'signed_off' : 'returned',
          'p_note': change.note,
          'p_at': change.at.toUtc().toIso8601String(),
        },
      ),
    },
  );
}
