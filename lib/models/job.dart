/// Where a job stands.
enum JobStatus {
  /// Given to the trainee, not finished yet.
  assigned,

  /// The trainee says it is done, with the time it took; waiting for a supervisor.
  done,

  /// A supervisor checked it and confirmed the time that counts.
  checked,

  /// Called off before the trainee finished it.
  cancelled;

  static JobStatus fromWire(String? value) => JobStatus.values.where((s) => s.name == value).firstOrNull ?? assigned;
}

/// A job card: a real task on a real car, given by a supervisor to one trainee, practising some skills of the
/// checklist. The trainee marks it done with the minutes it took; the supervisor checks it and those minutes become
/// hands-on hours.
class Job {
  const Job({
    required this.id,
    required this.workshopId,
    required this.traineeId,
    required this.title,
    required this.assignedAt,
    this.assignedBy,
    this.vehicle = '',
    this.skillCodes = const [],
    this.status = JobStatus.assigned,
    this.minutes,
    this.note = '',
    this.doneAt,
    this.checkedMinutes,
    this.checkNote = '',
    this.checkedAt,
  });

  factory Job.fromJson(Map<String, Object?> json) => Job(
    id: json['id']! as String,
    workshopId: json['workshop_id']! as String,
    traineeId: json['trainee_id']! as String,
    assignedBy: json['assigned_by'] as String?,
    title: json['title']! as String,
    vehicle: json['vehicle'] as String? ?? '',
    skillCodes: [for (final c in json['skill_codes'] as List<Object?>? ?? const []) c! as String],
    status: JobStatus.fromWire(json['status'] as String?),
    assignedAt: DateTime.parse(json['assigned_at']! as String),
    minutes: (json['minutes'] as num?)?.toInt(),
    note: json['note'] as String? ?? '',
    doneAt: _time(json['done_at']),
    checkedMinutes: (json['checked_minutes'] as num?)?.toInt(),
    checkNote: json['check_note'] as String? ?? '',
    checkedAt: _time(json['checked_at']),
  );

  /// Made on the phone that gave the job.
  final String id;
  final String workshopId;
  final String traineeId;
  final String? assignedBy;
  final String title;
  final String vehicle;
  final List<String> skillCodes;
  final JobStatus status;
  final DateTime assignedAt;

  /// What the trainee said it took.
  final int? minutes;
  final String note;
  final DateTime? doneAt;

  /// What the supervisor confirmed; this is what counts.
  final int? checkedMinutes;
  final String checkNote;
  final DateTime? checkedAt;

  /// Still on the trainee's list: given and not yet finished.
  bool get open => status == JobStatus.assigned;

  Map<String, Object?> toJson() => {
    'id': id,
    'workshop_id': workshopId,
    'trainee_id': traineeId,
    'assigned_by': assignedBy,
    'title': title,
    'vehicle': vehicle,
    'skill_codes': skillCodes,
    'status': status.name,
    'assigned_at': assignedAt.toUtc().toIso8601String(),
    'minutes': minutes,
    'note': note,
    'done_at': doneAt?.toUtc().toIso8601String(),
    'checked_minutes': checkedMinutes,
    'check_note': checkNote,
    'checked_at': checkedAt?.toUtc().toIso8601String(),
  };

  Job copyWith({JobStatus? status, int? minutes, String? note, DateTime? doneAt, int? checkedMinutes, String? checkNote, DateTime? checkedAt}) => Job(
    id: id,
    workshopId: workshopId,
    traineeId: traineeId,
    assignedBy: assignedBy,
    title: title,
    vehicle: vehicle,
    skillCodes: skillCodes,
    status: status ?? this.status,
    assignedAt: assignedAt,
    minutes: minutes ?? this.minutes,
    note: note ?? this.note,
    doneAt: doneAt ?? this.doneAt,
    checkedMinutes: checkedMinutes ?? this.checkedMinutes,
    checkNote: checkNote ?? this.checkNote,
    checkedAt: checkedAt ?? this.checkedAt,
  );

  @override
  bool operator ==(Object other) => other is Job && _same(toJson(), other.toJson());

  @override
  int get hashCode => Object.hash(id, status, minutes, checkedMinutes, note, checkNote);
}

/// One trainee's shift: when they checked in and out, and whether a supervisor confirmed it.
class Shift {
  const Shift({required this.id, required this.workshopId, required this.traineeId, required this.checkIn, this.checkOut, this.confirmedAt});

  factory Shift.fromJson(Map<String, Object?> json) => Shift(
    id: json['id']! as String,
    workshopId: json['workshop_id']! as String,
    traineeId: json['trainee_id']! as String,
    checkIn: DateTime.parse(json['check_in']! as String),
    checkOut: _time(json['check_out']),
    confirmedAt: _time(json['confirmed_at']),
  );

  /// Made on the trainee's phone at check-in.
  final String id;
  final String workshopId;
  final String traineeId;
  final DateTime checkIn;
  final DateTime? checkOut;
  final DateTime? confirmedAt;

  /// Checked in, not out yet.
  bool get open => checkOut == null;
  bool get confirmed => confirmedAt != null;

  /// How long it lasted, or null while it is open.
  Duration? get length => checkOut?.difference(checkIn);

  Map<String, Object?> toJson() => {
    'id': id,
    'workshop_id': workshopId,
    'trainee_id': traineeId,
    'check_in': checkIn.toUtc().toIso8601String(),
    'check_out': checkOut?.toUtc().toIso8601String(),
    'confirmed_at': confirmedAt?.toUtc().toIso8601String(),
  };

  Shift copyWith({DateTime? checkIn, DateTime? checkOut, DateTime? confirmedAt}) => Shift(
    id: id,
    workshopId: workshopId,
    traineeId: traineeId,
    checkIn: checkIn ?? this.checkIn,
    checkOut: checkOut ?? this.checkOut,
    confirmedAt: confirmedAt ?? this.confirmedAt,
  );

  @override
  bool operator ==(Object other) => other is Shift && _same(toJson(), other.toJson());

  @override
  int get hashCode => Object.hash(id, checkIn, checkOut, confirmedAt);
}

/// A trainee's hours: what a supervisor has confirmed, and what still waits for one.
class Hours {
  const Hours({this.workshop = Duration.zero, this.workshopWaiting = Duration.zero, this.handsOn = Duration.zero, this.handsOnWaiting = Duration.zero});

  /// Adds up [traineeId]'s shifts and jobs. Open shifts and called-off jobs count for nothing yet.
  factory Hours.of(String traineeId, Iterable<Shift> shifts, Iterable<Job> jobs) {
    var workshop = Duration.zero;
    var workshopWaiting = Duration.zero;
    var handsOn = Duration.zero;
    var handsOnWaiting = Duration.zero;
    for (final s in shifts.where((s) => s.traineeId == traineeId)) {
      final length = s.length;
      if (length == null) continue;
      if (s.confirmed) {
        workshop += length;
      } else {
        workshopWaiting += length;
      }
    }
    for (final j in jobs.where((j) => j.traineeId == traineeId)) {
      if (j.status == JobStatus.checked) handsOn += Duration(minutes: j.checkedMinutes ?? j.minutes ?? 0);
      if (j.status == JobStatus.done) handsOnWaiting += Duration(minutes: j.minutes ?? 0);
    }
    return Hours(workshop: workshop, workshopWaiting: workshopWaiting, handsOn: handsOn, handsOnWaiting: handsOnWaiting);
  }

  /// From check-in to check-out, on shifts a supervisor confirmed.
  final Duration workshop;
  final Duration workshopWaiting;

  /// On jobs a supervisor checked.
  final Duration handsOn;
  final Duration handsOnWaiting;

  @override
  bool operator ==(Object other) =>
      other is Hours &&
      other.workshop == workshop &&
      other.workshopWaiting == workshopWaiting &&
      other.handsOn == handsOn &&
      other.handsOnWaiting == handsOnWaiting;

  @override
  int get hashCode => Object.hash(workshop, workshopWaiting, handsOn, handsOnWaiting);

  @override
  String toString() => 'Hours(workshop: $workshop + $workshopWaiting waiting, hands-on: $handsOn + $handsOnWaiting waiting)';
}

DateTime? _time(Object? value) => switch (value) {
  final String at => DateTime.parse(at),
  _ => null,
};

bool _same(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    final other = b[e.key];
    if (e.value is List && other is List) {
      final x = e.value! as List;
      if (x.length != other.length) return false;
      for (var i = 0; i < x.length; i++) {
        if (x[i] != other[i]) return false;
      }
    } else if (e.value != other) {
      return false;
    }
  }
  return true;
}
