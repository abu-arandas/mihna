import 'package:supabase/supabase.dart';

import '../models/change.dart';
import '../models/job.dart';
import '../models/skill_record.dart';
import 'workshop_service.dart';

/// The skill records, jobs and shifts of a workshop, and sending the changes the phone queued
/// (lib/services/change_queue.dart).
abstract interface class LogbookService {
  /// The records the caller may see in [workshopId]: their own for a trainee, everyone's for a supervisor.
  Future<List<SkillRecord>> records(String workshopId);

  /// The jobs the caller may see in [workshopId], the same way.
  Future<List<Job>> jobs(String workshopId);

  /// The shifts the caller may see in [workshopId], the same way, oldest first.
  Future<List<Shift>> shifts(String workshopId);

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
  Future<List<Job>> jobs(String workshopId) async {
    final rows = await _client.from('jobs').select().eq('workshop_id', workshopId).order('assigned_at');
    return [for (final row in rows) Job.fromJson(row)];
  }

  @override
  Future<List<Shift>> shifts(String workshopId) async {
    final rows = await _client.from('shifts').select().eq('workshop_id', workshopId).order('check_in');
    return [for (final row in rows) Shift.fromJson(row)];
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
      AssignJobChange(:final job) => _client.rpc<void>(
        'assign_job',
        params: {
          'p_id': job.id,
          'p_workshop': change.workshopId,
          'p_trainee': job.traineeId,
          'p_title': job.title,
          'p_vehicle': job.vehicle,
          'p_skills': job.skillCodes,
          'p_at': change.at.toUtc().toIso8601String(),
        },
      ),
      FinishJobChange() => _client.rpc<void>(
        'finish_job',
        params: {'p_id': change.jobId, 'p_minutes': change.minutes, 'p_note': change.note, 'p_at': change.at.toUtc().toIso8601String()},
      ),
      CheckJobChange() => _client.rpc<void>(
        'check_job',
        params: {'p_id': change.jobId, 'p_minutes': change.minutes, 'p_note': change.note, 'p_at': change.at.toUtc().toIso8601String()},
      ),
      CancelJobChange() => _client.rpc<void>('cancel_job', params: {'p_id': change.jobId}),
      CheckInChange() => _client.rpc<void>(
        'check_in',
        params: {'p_id': change.shiftId, 'p_workshop': change.workshopId, 'p_at': change.at.toUtc().toIso8601String()},
      ),
      CheckOutChange() => _client.rpc<void>('check_out', params: {'p_id': change.shiftId, 'p_at': change.at.toUtc().toIso8601String()}),
      ConfirmShiftChange() => _client.rpc<void>(
        'confirm_shift',
        params: {
          'p_id': change.shiftId,
          'p_check_in': change.checkIn.toUtc().toIso8601String(),
          'p_check_out': change.checkOut.toUtc().toIso8601String(),
          'p_at': change.at.toUtc().toIso8601String(),
        },
      ),
    },
  );
}
