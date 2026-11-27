import 'dart:math';

import 'job.dart';
import 'skill_record.dart';

/// Something a person did on the phone that the server has not heard about yet: logging practice or reviewing it,
/// giving out, finishing or checking a job, and checking in, out, or confirming a shift.
///
/// A change is safe to send more than once (the database functions are idempotent), so the queue can resend it
/// whenever it is not sure the last try arrived.
sealed class Change {
  const Change({required this.id, required this.workshopId, required this.at});

  factory Change.fromJson(Map<String, Object?> json) => switch (json['kind']) {
    'practise' => PractiseChange(
      id: json['id']! as String,
      workshopId: json['workshop_id']! as String,
      traineeId: json['trainee_id']! as String,
      skillCode: json['skill_code']! as String,
      note: json['note'] as String? ?? '',
      at: DateTime.parse(json['at']! as String),
    ),
    'review' => ReviewChange(
      id: json['id']! as String,
      workshopId: json['workshop_id']! as String,
      traineeId: json['trainee_id']! as String,
      skillCode: json['skill_code']! as String,
      signedOff: json['signed_off']! as bool,
      note: json['note'] as String? ?? '',
      at: DateTime.parse(json['at']! as String),
    ),
    'assign_job' => AssignJobChange(
      id: json['id']! as String,
      workshopId: json['workshop_id']! as String,
      job: Job.fromJson(json['job']! as Map<String, Object?>),
      at: DateTime.parse(json['at']! as String),
    ),
    'finish_job' => FinishJobChange(
      id: json['id']! as String,
      workshopId: json['workshop_id']! as String,
      jobId: json['job_id']! as String,
      minutes: (json['minutes']! as num).toInt(),
      note: json['note'] as String? ?? '',
      at: DateTime.parse(json['at']! as String),
    ),
    'check_job' => CheckJobChange(
      id: json['id']! as String,
      workshopId: json['workshop_id']! as String,
      jobId: json['job_id']! as String,
      minutes: (json['minutes']! as num).toInt(),
      note: json['note'] as String? ?? '',
      at: DateTime.parse(json['at']! as String),
    ),
    'cancel_job' => CancelJobChange(
      id: json['id']! as String,
      workshopId: json['workshop_id']! as String,
      jobId: json['job_id']! as String,
      at: DateTime.parse(json['at']! as String),
    ),
    'check_in' => CheckInChange(
      id: json['id']! as String,
      workshopId: json['workshop_id']! as String,
      shiftId: json['shift_id']! as String,
      traineeId: json['trainee_id']! as String,
      at: DateTime.parse(json['at']! as String),
    ),
    'check_out' => CheckOutChange(
      id: json['id']! as String,
      workshopId: json['workshop_id']! as String,
      shiftId: json['shift_id']! as String,
      at: DateTime.parse(json['at']! as String),
    ),
    'confirm_shift' => ConfirmShiftChange(
      id: json['id']! as String,
      workshopId: json['workshop_id']! as String,
      shiftId: json['shift_id']! as String,
      checkIn: DateTime.parse(json['check_in']! as String),
      checkOut: DateTime.parse(json['check_out']! as String),
      at: DateTime.parse(json['at']! as String),
    ),
    final kind => throw FormatException('Unknown change: $kind'),
  };

  /// Made on the phone, so the queue can tell its entries apart.
  final String id;
  final String workshopId;

  /// When the person did it, kept as the time of the work rather than of the upload.
  final DateTime at;

  /// Two changes with the same target: the later one replaces the earlier while both wait to be sent.
  String get target;

  Map<String, Object?> toJson();
}

/// A change to one trainee's record of one skill.
sealed class SkillChange extends Change {
  const SkillChange({required super.id, required super.workshopId, required super.at});

  String get traineeId;
  String get skillCode;

  /// The record it changes: [SkillRecord.key].
  String get recordKey => '$traineeId/$skillCode';

  /// What the record looks like once the server has this change, given what it looked like before.
  SkillRecord? applyTo(SkillRecord? before);
}

/// A trainee practised a skill.
class PractiseChange extends SkillChange {
  const PractiseChange({required super.id, required super.workshopId, required this.traineeId, required this.skillCode, required this.note, required super.at});

  @override
  final String traineeId;
  @override
  final String skillCode;
  final String note;

  @override
  String get target => 'practise/$workshopId/$traineeId/$skillCode';

  @override
  SkillRecord applyTo(SkillRecord? before) {
    if (before != null && before.status == SkillStatus.signedOff) return before;
    return SkillRecord(workshopId: workshopId, traineeId: traineeId, skillCode: skillCode, status: SkillStatus.practised, note: note, practisedAt: at);
  }

  @override
  Map<String, Object?> toJson() => {
    'kind': 'practise',
    'id': id,
    'workshop_id': workshopId,
    'trainee_id': traineeId,
    'skill_code': skillCode,
    'note': note,
    'at': at.toUtc().toIso8601String(),
  };
}

/// A supervisor signed a skill off, or sent it back.
class ReviewChange extends SkillChange {
  const ReviewChange({
    required super.id,
    required super.workshopId,
    required this.traineeId,
    required this.skillCode,
    required this.signedOff,
    required this.note,
    required super.at,
  });

  @override
  final String traineeId;
  @override
  final String skillCode;
  final bool signedOff;
  final String note;

  @override
  String get target => 'review/$workshopId/$traineeId/$skillCode';

  @override
  SkillRecord? applyTo(SkillRecord? before) {
    if (before == null || before.status == SkillStatus.signedOff) return before;
    return before.copyWith(status: signedOff ? SkillStatus.signedOff : SkillStatus.returned, reviewNote: note, reviewedAt: at);
  }

  @override
  Map<String, Object?> toJson() => {
    'kind': 'review',
    'id': id,
    'workshop_id': workshopId,
    'trainee_id': traineeId,
    'skill_code': skillCode,
    'signed_off': signedOff,
    'note': note,
    'at': at.toUtc().toIso8601String(),
  };
}

/// A change to one job.
sealed class JobChange extends Change {
  const JobChange({required super.id, required super.workshopId, required super.at});

  String get jobId;

  /// What the job looks like once the server has this change, given what it looked like before.
  Job? applyTo(Job? before);
}

/// A supervisor gave a trainee a job (or, while it is still open, changed it).
class AssignJobChange extends JobChange {
  const AssignJobChange({required super.id, required super.workshopId, required this.job, required super.at});

  final Job job;

  @override
  String get jobId => job.id;

  @override
  String get target => 'job/$jobId/assign';

  @override
  Job applyTo(Job? before) => before == null || before.open ? job : before;

  @override
  Map<String, Object?> toJson() => {'kind': 'assign_job', 'id': id, 'workshop_id': workshopId, 'job': job.toJson(), 'at': at.toUtc().toIso8601String()};
}

/// The trainee finished their job, in [minutes].
class FinishJobChange extends JobChange {
  const FinishJobChange({required super.id, required super.workshopId, required this.jobId, required this.minutes, required this.note, required super.at});

  @override
  final String jobId;
  final int minutes;
  final String note;

  @override
  String get target => 'job/$jobId/finish';

  @override
  Job? applyTo(Job? before) {
    if (before == null || before.status == JobStatus.checked || before.status == JobStatus.cancelled) return before;
    return before.copyWith(status: JobStatus.done, minutes: minutes, note: note, doneAt: at);
  }

  @override
  Map<String, Object?> toJson() => {
    'kind': 'finish_job',
    'id': id,
    'workshop_id': workshopId,
    'job_id': jobId,
    'minutes': minutes,
    'note': note,
    'at': at.toUtc().toIso8601String(),
  };
}

/// A supervisor checked a finished job and confirmed [minutes] of hands-on time.
class CheckJobChange extends JobChange {
  const CheckJobChange({required super.id, required super.workshopId, required this.jobId, required this.minutes, required this.note, required super.at});

  @override
  final String jobId;
  final int minutes;
  final String note;

  @override
  String get target => 'job/$jobId/check';

  @override
  Job? applyTo(Job? before) {
    if (before == null || before.status != JobStatus.done) return before;
    return before.copyWith(status: JobStatus.checked, checkedMinutes: minutes, checkNote: note, checkedAt: at);
  }

  @override
  Map<String, Object?> toJson() => {
    'kind': 'check_job',
    'id': id,
    'workshop_id': workshopId,
    'job_id': jobId,
    'minutes': minutes,
    'note': note,
    'at': at.toUtc().toIso8601String(),
  };
}

/// A supervisor called off a job the trainee had not finished.
class CancelJobChange extends JobChange {
  const CancelJobChange({required super.id, required super.workshopId, required this.jobId, required super.at});

  @override
  final String jobId;

  @override
  String get target => 'job/$jobId/cancel';

  @override
  Job? applyTo(Job? before) => before != null && before.open ? before.copyWith(status: JobStatus.cancelled) : before;

  @override
  Map<String, Object?> toJson() => {'kind': 'cancel_job', 'id': id, 'workshop_id': workshopId, 'job_id': jobId, 'at': at.toUtc().toIso8601String()};
}

/// A change to one shift.
sealed class ShiftChange extends Change {
  const ShiftChange({required super.id, required super.workshopId, required super.at});

  String get shiftId;

  /// What the shift looks like once the server has this change, given what it looked like before.
  Shift? applyTo(Shift? before);
}

/// A trainee checked in, starting shift [shiftId].
class CheckInChange extends ShiftChange {
  const CheckInChange({required super.id, required super.workshopId, required this.shiftId, required this.traineeId, required super.at});

  @override
  final String shiftId;
  final String traineeId;

  @override
  String get target => 'shift/$shiftId/in';

  @override
  Shift applyTo(Shift? before) => before ?? Shift(id: shiftId, workshopId: workshopId, traineeId: traineeId, checkIn: at);

  @override
  Map<String, Object?> toJson() => {
    'kind': 'check_in',
    'id': id,
    'workshop_id': workshopId,
    'shift_id': shiftId,
    'trainee_id': traineeId,
    'at': at.toUtc().toIso8601String(),
  };
}

/// A trainee checked out of shift [shiftId].
class CheckOutChange extends ShiftChange {
  const CheckOutChange({required super.id, required super.workshopId, required this.shiftId, required super.at});

  @override
  final String shiftId;

  @override
  String get target => 'shift/$shiftId/out';

  @override
  Shift? applyTo(Shift? before) => before != null && before.open ? before.copyWith(checkOut: at) : before;

  @override
  Map<String, Object?> toJson() => {'kind': 'check_out', 'id': id, 'workshop_id': workshopId, 'shift_id': shiftId, 'at': at.toUtc().toIso8601String()};
}

/// A supervisor confirmed shift [shiftId] with these times: the trainee's, or a correction.
class ConfirmShiftChange extends ShiftChange {
  const ConfirmShiftChange({
    required super.id,
    required super.workshopId,
    required this.shiftId,
    required this.checkIn,
    required this.checkOut,
    required super.at,
  });

  @override
  final String shiftId;
  final DateTime checkIn;
  final DateTime checkOut;

  @override
  String get target => 'shift/$shiftId/confirm';

  @override
  Shift? applyTo(Shift? before) => before == null || before.confirmed ? before : before.copyWith(checkIn: checkIn, checkOut: checkOut, confirmedAt: at);

  @override
  Map<String, Object?> toJson() => {
    'kind': 'confirm_shift',
    'id': id,
    'workshop_id': workshopId,
    'shift_id': shiftId,
    'check_in': checkIn.toUtc().toIso8601String(),
    'check_out': checkOut.toUtc().toIso8601String(),
    'at': at.toUtc().toIso8601String(),
  };
}

final _random = Random.secure();

/// A random (version 4) UUID, made on the phone so a change has an id before it reaches the server.
String newId() {
  final b = List<int>.generate(16, (_) => _random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final hex = [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
