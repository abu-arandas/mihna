import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';

import '../models/change.dart';
import '../models/job.dart';
import '../models/membership.dart';
import '../models/skill_record.dart';
import '../services/change_queue.dart';
import '../services/local_store.dart';
import '../services/logbook_service.dart';

/// The skill records, jobs and shifts of the open workshop, and the queue that gets the phone's changes to the server.
///
/// What a page shows is the server's last copy with every unsent change laid over it, so a trainee sees their
/// practice logged, their job done or their check-in the moment they tap, signal or not. The queue is tried on every
/// change, every 30 seconds while anything waits, and on a pull to refresh.
class LogbookController extends GetxController {
  LogbookController(this._service, this._store, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final LogbookService _service;
  final LocalStore _store;
  final DateTime Function() _clock;

  /// The server's copies: records by [SkillRecord.key], jobs and shifts by id.
  final _server = <String, SkillRecord>{};
  final _serverJobs = <String, Job>{};
  final _serverShifts = <String, Shift>{};

  /// What the pages show: the server's copies with the queue laid over them.
  final records = <String, SkillRecord>{}.obs;
  final jobs = <String, Job>{}.obs;
  final shifts = <String, Shift>{}.obs;

  final pendingCount = 0.obs;
  final rejected = <Rejection>[].obs;
  final syncing = false.obs;

  /// True when the last try to reach the server failed.
  final offline = false.obs;
  final lastSynced = Rxn<DateTime>();
  final error = RxnString();

  Membership? _open;
  ChangeQueue? _queue;
  StreamSubscription<void>? _queueChanges;
  Timer? _timer;

  Membership? get membership => _open;

  /// Opens [membership]'s workshop: the phone's copy at once, then the server's.
  Future<void> open(Membership membership) async {
    if (_open?.workshopId == membership.workshopId && _open?.userId == membership.userId) return;
    await _closeQueue();
    _open = membership;
    _server.clear();
    _serverJobs.clear();
    _serverShifts.clear();
    records.clear();
    jobs.clear();
    shifts.clear();
    final queue = _queue = ChangeQueue(_store, _service.send, key: 'mihna.queue.${membership.userId}');
    _queueChanges = queue.changes.listen((_) => _refreshView());
    await queue.load();
    await _readCache(_cacheKey('records'), _server, SkillRecord.fromJson, (r) => r.key);
    await _readCache(_cacheKey('jobs'), _serverJobs, Job.fromJson, (j) => j.id);
    await _readCache(_cacheKey('shifts'), _serverShifts, Shift.fromJson, (s) => s.id);
    _refreshView();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (pendingCount.value > 0) unawaited(sync());
    });
    await sync();
  }

  String _cacheKey(String what) => 'mihna.$what.${_open?.workshopId}.${_open?.userId}';

  Future<void> _readCache<T>(String key, Map<String, T> into, T Function(Map<String, Object?>) read, String Function(T) id) async {
    try {
      final saved = await _store.read(key);
      if (saved == null) return;
      for (final row in jsonDecode(saved) as List<Object?>) {
        final item = read(row! as Map<String, Object?>);
        into[id(item)] = item;
      }
    } on Object {
      // Unreadable copy: the server's replaces it.
      into.clear();
    }
  }

  /// The record of [traineeId] on [skillCode], or null when they have not started it.
  SkillRecord? recordOf(String traineeId, String skillCode) => records['$traineeId/$skillCode'];

  /// [traineeId]'s jobs, newest first, called-off ones left out.
  List<Job> jobsOf(String traineeId) =>
      jobs.values.where((j) => j.traineeId == traineeId && j.status != JobStatus.cancelled).toList()..sort((a, b) => b.assignedAt.compareTo(a.assignedAt));

  /// [traineeId]'s shifts, newest first.
  List<Shift> shiftsOf(String traineeId) => shifts.values.where((s) => s.traineeId == traineeId).toList()..sort((a, b) => b.checkIn.compareTo(a.checkIn));

  /// The shift [traineeId] is checked in to, if any.
  Shift? openShiftOf(String traineeId) => shifts.values.where((s) => s.traineeId == traineeId && s.open).firstOrNull;

  Hours hoursOf(String traineeId) => Hours.of(traineeId, shifts.values, jobs.values);

  /// The signed-in trainee practised a skill.
  Future<void> practise(String skillCode, String note) =>
      _queueChange((m) => PractiseChange(id: newId(), workshopId: m.workshopId, traineeId: m.userId, skillCode: skillCode, note: note.trim(), at: _clock()));

  /// The signed-in supervisor signed a trainee's skill off, or sent it back.
  Future<void> review(String traineeId, String skillCode, {required bool signedOff, String note = ''}) => _queueChange(
    (m) =>
        ReviewChange(id: newId(), workshopId: m.workshopId, traineeId: traineeId, skillCode: skillCode, signedOff: signedOff, note: note.trim(), at: _clock()),
  );

  /// The signed-in supervisor gives [traineeId] a job.
  Future<void> assignJob({required String traineeId, required String title, String vehicle = '', List<String> skillCodes = const []}) => _queueChange((m) {
    final at = _clock();
    final job = Job(
      id: newId(),
      workshopId: m.workshopId,
      traineeId: traineeId,
      assignedBy: m.userId,
      title: title.trim(),
      vehicle: vehicle.trim(),
      skillCodes: skillCodes,
      assignedAt: at,
    );
    return AssignJobChange(id: newId(), workshopId: m.workshopId, job: job, at: at);
  });

  /// The signed-in trainee finished [job] in [minutes]. Each of the job's skills not yet signed off is logged as
  /// practised too, with the job as its note, so the supervisor sees them waiting for sign-off.
  Future<void> finishJob(Job job, {required int minutes, String note = ''}) async {
    await _queueChange((m) => FinishJobChange(id: newId(), workshopId: m.workshopId, jobId: job.id, minutes: minutes, note: note.trim(), at: _clock()));
    final m = _open;
    if (m == null) return;
    var what = [job.title, if (job.vehicle.isNotEmpty) job.vehicle, if (note.trim().isNotEmpty) note.trim()].join(' · ');
    if (what.length > 1000) what = what.substring(0, 1000);
    for (final code in job.skillCodes) {
      if (recordOf(m.userId, code)?.status == SkillStatus.signedOff) continue;
      await practise(code, what);
    }
  }

  /// The signed-in supervisor checked [job] and confirms [minutes] of hands-on time.
  Future<void> checkJob(Job job, {required int minutes, String note = ''}) =>
      _queueChange((m) => CheckJobChange(id: newId(), workshopId: m.workshopId, jobId: job.id, minutes: minutes, note: note.trim(), at: _clock()));

  /// The signed-in supervisor called off [job].
  Future<void> cancelJob(Job job) => _queueChange((m) => CancelJobChange(id: newId(), workshopId: m.workshopId, jobId: job.id, at: _clock()));

  /// The signed-in trainee checks in. Does nothing while they are checked in already.
  Future<void> checkIn() async {
    final m = _open;
    if (m == null || openShiftOf(m.userId) != null) return;
    await _queueChange((m) => CheckInChange(id: newId(), workshopId: m.workshopId, shiftId: newId(), traineeId: m.userId, at: _clock()));
  }

  /// The signed-in trainee checks out of the shift they are in.
  Future<void> checkOut() async {
    final m = _open;
    final shift = m == null ? null : openShiftOf(m.userId);
    if (shift == null) return;
    await _queueChange((m) => CheckOutChange(id: newId(), workshopId: m.workshopId, shiftId: shift.id, at: _clock()));
  }

  /// The signed-in supervisor confirms [shift] with these times.
  Future<void> confirmShift(Shift shift, {required DateTime checkIn, required DateTime checkOut}) =>
      _queueChange((m) => ConfirmShiftChange(id: newId(), workshopId: m.workshopId, shiftId: shift.id, checkIn: checkIn, checkOut: checkOut, at: _clock()));

  Future<void> _queueChange(Change Function(Membership m) make) async {
    final m = _open;
    final queue = _queue;
    if (m == null || queue == null) return;
    try {
      await queue.add(make(m));
    } on Object {
      error.value = 'Could not save on this phone. Try again.';
      return;
    }
    unawaited(sync());
  }

  /// Sends what waits, then reads the server's records, jobs and shifts again.
  Future<void> sync() async {
    final queue = _queue;
    final m = _open;
    if (queue == null || m == null || syncing.value) return;
    syncing.value = true;
    try {
      final result = await queue.flush();
      if (result.offline) {
        offline.value = true;
        return;
      }
      final (fresh, freshJobs, freshShifts) = await (_service.records(m.workshopId), _service.jobs(m.workshopId), _service.shifts(m.workshopId)).wait;
      if (!identical(_open, m)) return;
      _server
        ..clear()
        ..addAll({for (final r in fresh) r.key: r});
      _serverJobs
        ..clear()
        ..addAll({for (final j in freshJobs) j.id: j});
      _serverShifts
        ..clear()
        ..addAll({for (final s in freshShifts) s.id: s});
      await _store.write(_cacheKey('records'), jsonEncode([for (final r in fresh) r.toJson()]));
      await _store.write(_cacheKey('jobs'), jsonEncode([for (final j in freshJobs) j.toJson()]));
      await _store.write(_cacheKey('shifts'), jsonEncode([for (final s in freshShifts) s.toJson()]));
      offline.value = false;
      lastSynced.value = _clock();
    } on Object {
      offline.value = true;
    } finally {
      syncing.value = false;
      _refreshView();
    }
  }

  Future<void> dismissRejected() async => _queue?.dismissRejected();

  void _refreshView() {
    final queue = _queue;
    final view = Map<String, SkillRecord>.of(_server);
    final jobView = Map<String, Job>.of(_serverJobs);
    final shiftView = Map<String, Shift>.of(_serverShifts);
    for (final change in queue?.pending ?? const <Change>[]) {
      switch (change) {
        case SkillChange():
          final after = change.applyTo(view[change.recordKey]);
          if (after != null) view[change.recordKey] = after;
        case JobChange():
          final after = change.applyTo(jobView[change.jobId]);
          if (after != null) jobView[change.jobId] = after;
        case ShiftChange():
          final after = change.applyTo(shiftView[change.shiftId]);
          if (after != null) shiftView[change.shiftId] = after;
      }
    }
    records.assignAll(view);
    jobs.assignAll(jobView);
    shifts.assignAll(shiftView);
    pendingCount.value = queue?.pending.length ?? 0;
    rejected.assignAll(queue?.rejected ?? const []);
  }

  Future<void> _closeQueue() async {
    _timer?.cancel();
    await _queueChanges?.cancel();
    await _queue?.close();
    _queue = null;
  }

  @override
  void onClose() {
    unawaited(_closeQueue());
    super.onClose();
  }
}
