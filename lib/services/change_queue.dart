import 'dart:async';
import 'dart:convert';

import '../models/change.dart';
import 'local_store.dart';

/// The server turned a change down for good (the person lost their role, the skill was already signed off). Sending
/// it again will not help, so the queue sets it aside and says why.
class RejectedChange implements Exception {
  const RejectedChange(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A change the server turned down, with its reason.
typedef Rejection = ({Change change, String reason});

/// What one [ChangeQueue.flush] did.
typedef FlushResult = ({int sent, int rejected, bool offline});

/// Every change made on the phone, kept on the phone until the server has it.
///
/// Changes are saved before anything is sent, and sent oldest first. A failure that may be the network (anything but
/// a [RejectedChange]) stops the run and leaves the change at the front, to be sent next time. A rejection sets the
/// change aside, so one bad change never blocks the rest. While waiting, a newer change to the same target replaces
/// the older one, so a weak signal never replays a trainee's three edits of the same note.
class ChangeQueue {
  ChangeQueue(this._store, this._send, {this.key = 'mihna.queue'});

  final LocalStore _store;
  final Future<void> Function(Change change) _send;

  /// Where the queue lives in [LocalStore]; one per signed-in person.
  final String key;

  final _pending = <Change>[];
  final _rejected = <Rejection>[];
  final _changes = StreamController<void>.broadcast();
  Future<FlushResult>? _running;
  bool _loaded = false;

  /// Changes waiting to be sent, oldest first.
  List<Change> get pending => List.unmodifiable(_pending);

  /// Changes the server turned down, newest last.
  List<Rejection> get rejected => List.unmodifiable(_rejected);

  /// Fires whenever [pending] or [rejected] changes.
  Stream<void> get changes => _changes.stream;

  /// Reads what an earlier run left. Safe to call more than once.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final saved = await _store.read(key);
    if (saved == null) return;
    try {
      final json = jsonDecode(saved) as Map<String, Object?>;
      _pending.addAll([for (final c in json['pending']! as List<Object?>) Change.fromJson(c! as Map<String, Object?>)]);
      for (final r in json['rejected'] as List<Object?>? ?? const []) {
        final row = r! as Map<String, Object?>;
        _rejected.add((change: Change.fromJson(row['change']! as Map<String, Object?>), reason: row['reason']! as String));
      }
    } on Object {
      // A queue this build cannot read (written by a newer one): keep it under another key rather than lose it.
      await _store.write('$key.unreadable', saved);
      await _store.remove(key);
    }
    _changes.add(null);
  }

  /// Saves [change] on the phone. It is sent by the next [flush].
  Future<void> add(Change change) async {
    await load();
    _pending
      ..removeWhere((c) => c.target == change.target)
      ..add(change);
    await _save();
  }

  /// Sends every pending change it can, oldest first. Calls made while one is running share its result.
  Future<FlushResult> flush() => _running ??= _flush().whenComplete(() => _running = null);

  Future<FlushResult> _flush() async {
    await load();
    var sent = 0;
    var rejected = 0;
    while (_pending.isNotEmpty) {
      final change = _pending.first;
      try {
        await _send(change);
        sent++;
      } on RejectedChange catch (e) {
        rejected++;
        _rejected.add((change: change, reason: e.message));
      } on Object {
        // Most likely no signal. It stays at the front for next time.
        return (sent: sent, rejected: rejected, offline: true);
      }
      // By identity: if a newer change replaced it while it was on its way, the newer one stays to be sent.
      _pending.remove(change);
      await _save();
    }
    return (sent: sent, rejected: rejected, offline: false);
  }

  /// Forgets the changes the server turned down, once the person has seen them.
  Future<void> dismissRejected() async {
    _rejected.clear();
    await _save();
  }

  Future<void> _save() async {
    await _store.write(
      key,
      jsonEncode({
        'pending': [for (final c in _pending) c.toJson()],
        'rejected': [
          for (final r in _rejected) {'change': r.change.toJson(), 'reason': r.reason},
        ],
      }),
    );
    _changes.add(null);
  }

  Future<void> close() => _changes.close();
}
