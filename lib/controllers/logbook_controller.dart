import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';

import '../models/change.dart';
import '../models/membership.dart';
import '../models/skill_record.dart';
import '../services/change_queue.dart';
import '../services/local_store.dart';
import '../services/logbook_service.dart';

/// The skill records of the open workshop, and the queue that gets the phone's changes to the server.
///
/// What a page shows is the server's last copy with every unsent change laid over it, so a trainee sees their
/// practice logged the moment they tap, signal or not. The queue is tried on every change, every 30 seconds while
/// anything waits, and on a pull to refresh.
class LogbookController extends GetxController {
  LogbookController(this._service, this._store);

  final LogbookService _service;
  final LocalStore _store;

  /// The server's records, by [SkillRecord.key].
  final _server = <String, SkillRecord>{}.obs;

  /// What the pages show: [_server] with the queue laid over it.
  final records = <String, SkillRecord>{}.obs;

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
    records.clear();
    final queue = _queue = ChangeQueue(_store, _service.send, key: 'mihna.queue.${membership.userId}');
    _queueChanges = queue.changes.listen((_) => _refreshView());
    await queue.load();
    try {
      final saved = await _store.read(_cacheKey);
      if (saved != null) {
        _server.assignAll({
          for (final r in jsonDecode(saved) as List<Object?>)
            SkillRecord.fromJson(r! as Map<String, Object?>).key: SkillRecord.fromJson(r as Map<String, Object?>),
        });
      }
    } on Object {
      // Unreadable copy: the server's replaces it.
    }
    _refreshView();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (pendingCount.value > 0) unawaited(sync());
    });
    await sync();
  }

  String get _cacheKey => 'mihna.records.${_open?.workshopId}.${_open?.userId}';

  /// The record of [traineeId] on [skillCode], or null when they have not started it.
  SkillRecord? recordOf(String traineeId, String skillCode) => records['$traineeId/$skillCode'];

  /// The signed-in trainee practised a skill.
  Future<void> practise(String skillCode, String note) => _queueChange(
    (m) => PractiseChange(id: newId(), workshopId: m.workshopId, traineeId: m.userId, skillCode: skillCode, note: note.trim(), at: DateTime.now()),
  );

  /// The signed-in supervisor signed a trainee's skill off, or sent it back.
  Future<void> review(String traineeId, String skillCode, {required bool signedOff, String note = ''}) => _queueChange(
    (m) => ReviewChange(
      id: newId(),
      workshopId: m.workshopId,
      traineeId: traineeId,
      skillCode: skillCode,
      signedOff: signedOff,
      note: note.trim(),
      at: DateTime.now(),
    ),
  );

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

  /// Sends what waits, then reads the server's records again.
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
      final fresh = await _service.records(m.workshopId);
      if (!identical(_open, m)) return;
      _server.assignAll({for (final r in fresh) r.key: r});
      await _store.write(_cacheKey, jsonEncode([for (final r in fresh) r.toJson()]));
      offline.value = false;
      lastSynced.value = DateTime.now();
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
    for (final change in queue?.pending ?? const <Change>[]) {
      final key = switch (change) {
        PractiseChange(:final traineeId, :final skillCode) || ReviewChange(:final traineeId, :final skillCode) => '$traineeId/$skillCode',
      };
      final after = change.applyTo(view[key]);
      if (after != null) view[key] = after;
    }
    records.assignAll(view);
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
