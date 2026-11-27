import 'dart:math';

import 'skill_record.dart';

/// Something a person did on the phone that the server has not heard about yet: logging practice, or a review.
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
    final kind => throw FormatException('Unknown change: $kind'),
  };

  /// Made on the phone, so the queue can tell its entries apart.
  final String id;
  final String workshopId;

  /// When the person did it, kept as the time of the work rather than of the upload.
  final DateTime at;

  /// Two changes with the same target: the later one replaces the earlier while both wait to be sent.
  String get target;

  /// What the record looks like once the server has this change, given what it looked like before.
  SkillRecord? applyTo(SkillRecord? before);

  Map<String, Object?> toJson();
}

/// A trainee practised a skill.
class PractiseChange extends Change {
  const PractiseChange({required super.id, required super.workshopId, required this.traineeId, required this.skillCode, required this.note, required super.at});

  final String traineeId;
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
class ReviewChange extends Change {
  const ReviewChange({
    required super.id,
    required super.workshopId,
    required this.traineeId,
    required this.skillCode,
    required this.signedOff,
    required this.note,
    required super.at,
  });

  final String traineeId;
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

final _random = Random.secure();

/// A random (version 4) UUID, made on the phone so a change has an id before it reaches the server.
String newId() {
  final b = List<int>.generate(16, (_) => _random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final hex = [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
