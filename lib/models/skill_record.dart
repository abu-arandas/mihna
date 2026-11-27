/// Where a trainee stands on one skill.
enum SkillStatus {
  /// Not logged yet. Never stored: a skill with no record is not started.
  notStarted,

  /// Logged by the trainee, waiting for a supervisor.
  practised,

  /// A supervisor watched it and signed it off.
  signedOff,

  /// A supervisor sent it back with a note; the trainee practises it again.
  returned;

  /// The database's name for it (`signed_off`).
  String get wire => switch (this) {
    signedOff => 'signed_off',
    _ => name,
  };

  static SkillStatus fromWire(String? value) => SkillStatus.values.where((s) => s.wire == value).firstOrNull ?? notStarted;
}

/// One trainee's record of one skill in one workshop.
class SkillRecord {
  const SkillRecord({
    required this.workshopId,
    required this.traineeId,
    required this.skillCode,
    required this.status,
    required this.practisedAt,
    this.note = '',
    this.reviewNote = '',
    this.reviewedAt,
  });

  factory SkillRecord.fromJson(Map<String, Object?> json) => SkillRecord(
    workshopId: json['workshop_id']! as String,
    traineeId: json['trainee_id']! as String,
    skillCode: json['skill_code']! as String,
    status: SkillStatus.fromWire(json['status'] as String?),
    note: json['note'] as String? ?? '',
    practisedAt: DateTime.parse(json['practised_at']! as String),
    reviewNote: json['review_note'] as String? ?? '',
    reviewedAt: switch (json['reviewed_at']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
  );

  final String workshopId;
  final String traineeId;
  final String skillCode;
  final SkillStatus status;
  final String note;
  final DateTime practisedAt;
  final String reviewNote;
  final DateTime? reviewedAt;

  /// The record's identity: one per trainee and skill in a workshop.
  String get key => '$traineeId/$skillCode';

  Map<String, Object?> toJson() => {
    'workshop_id': workshopId,
    'trainee_id': traineeId,
    'skill_code': skillCode,
    'status': status.wire,
    'note': note,
    'practised_at': practisedAt.toUtc().toIso8601String(),
    'review_note': reviewNote,
    'reviewed_at': reviewedAt?.toUtc().toIso8601String(),
  };

  SkillRecord copyWith({SkillStatus? status, String? note, DateTime? practisedAt, String? reviewNote, DateTime? reviewedAt}) => SkillRecord(
    workshopId: workshopId,
    traineeId: traineeId,
    skillCode: skillCode,
    status: status ?? this.status,
    note: note ?? this.note,
    practisedAt: practisedAt ?? this.practisedAt,
    reviewNote: reviewNote ?? this.reviewNote,
    reviewedAt: reviewedAt ?? this.reviewedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is SkillRecord &&
      other.workshopId == workshopId &&
      other.traineeId == traineeId &&
      other.skillCode == skillCode &&
      other.status == status &&
      other.note == note &&
      other.practisedAt == practisedAt &&
      other.reviewNote == reviewNote &&
      other.reviewedAt == reviewedAt;

  @override
  int get hashCode => Object.hash(workshopId, traineeId, skillCode, status, note, practisedAt, reviewNote, reviewedAt);
}
