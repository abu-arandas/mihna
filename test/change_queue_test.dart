import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mihna/models/change.dart';
import 'package:mihna/models/job.dart';
import 'package:mihna/models/skill_record.dart';
import 'package:mihna/models/trade.dart';
import 'package:mihna/services/change_queue.dart';
import 'package:mihna/services/local_store.dart';

/// The phone's storage, kept in a map for the test.
class MapStore implements LocalStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// A server the test can switch off, refuse with, and watch.
class Server {
  final received = <Change>[];
  bool reachable = true;
  String? refuse;
  Completer<void>? hold;

  Future<void> send(Change change) async {
    if (hold != null) await hold!.future;
    if (!reachable) throw const SocketLike();
    if (refuse != null) throw RejectedChange(refuse!);
    received.add(change);
  }
}

class SocketLike implements Exception {
  const SocketLike();
}

PractiseChange practise(String skill, {String note = '', String trainee = 't1'}) =>
    PractiseChange(id: newId(), workshopId: 'w1', traineeId: trainee, skillCode: skill, note: note, at: DateTime.utc(2026, 11, 27, 9));

void main() {
  test('a change is kept on the phone before anything is sent, and survives a restart', () async {
    final store = MapStore();
    final server = Server()..reachable = false;
    final queue = ChangeQueue(store, server.send);
    await queue.add(practise('brakes.pads', note: 'Corolla'));
    final result = await queue.flush();
    expect(result.offline, isTrue);
    expect(queue.pending, hasLength(1));

    final reopened = ChangeQueue(store, server.send);
    await reopened.load();
    expect(reopened.pending.single, isA<PractiseChange>());
    expect((reopened.pending.single as PractiseChange).note, 'Corolla');

    server.reachable = true;
    final sent = await reopened.flush();
    expect(sent, (sent: 1, rejected: 0, offline: false));
    expect(reopened.pending, isEmpty);
    expect(server.received.single.target, 'practise/w1/t1/brakes.pads');
  });

  test('changes go oldest first, and no signal stops the run without losing the rest', () async {
    final server = Server();
    final queue = ChangeQueue(MapStore(), server.send);
    await queue.add(practise('a.one'));
    await queue.add(practise('a.two'));
    await queue.add(practise('a.three'));
    var calls = 0;
    final flaky = ChangeQueue(MapStore(), (c) async {
      if (++calls == 2) throw const SocketLike();
      await server.send(c);
    });
    for (final c in queue.pending) {
      await flaky.add(c);
    }
    final first = await flaky.flush();
    expect(first, (sent: 1, rejected: 0, offline: true));
    expect([for (final c in flaky.pending) (c as PractiseChange).skillCode], ['a.two', 'a.three']);
    final second = await flaky.flush();
    expect(second, (sent: 2, rejected: 0, offline: false));
    expect([for (final c in server.received) (c as PractiseChange).skillCode], ['a.one', 'a.two', 'a.three']);
  });

  test('a newer change to the same skill replaces the one waiting', () async {
    final server = Server()..reachable = false;
    final queue = ChangeQueue(MapStore(), server.send);
    await queue.add(practise('brakes.pads', note: 'first'));
    await queue.add(practise('service.oil'));
    await queue.add(practise('brakes.pads', note: 'second'));
    expect([for (final c in queue.pending) (c as PractiseChange).note], ['', 'second']);
  });

  test('a refused change is set aside with its reason and does not block the others', () async {
    final store = MapStore();
    final server = Server();
    final queue = ChangeQueue(store, (c) async {
      if ((c as PractiseChange).skillCode == 'bad.one') throw const RejectedChange('Only a trainee can log practice');
      await server.send(c);
    });
    await queue.add(practise('bad.one'));
    await queue.add(practise('good.one'));
    expect(await queue.flush(), (sent: 1, rejected: 1, offline: false));
    expect(queue.rejected.single.reason, 'Only a trainee can log practice');
    expect(queue.pending, isEmpty);

    final reopened = ChangeQueue(store, server.send);
    await reopened.load();
    expect(reopened.rejected, hasLength(1));
    await reopened.dismissRejected();
    expect(reopened.rejected, isEmpty);
  });

  test('a change made while an older one is on its way is not lost', () async {
    final server = Server()..hold = Completer<void>();
    final queue = ChangeQueue(MapStore(), server.send);
    await queue.add(practise('brakes.pads', note: 'first'));
    final running = queue.flush();
    await queue.add(practise('brakes.pads', note: 'second'));
    server.hold!.complete();
    server.hold = null;
    await running;
    await queue.flush();
    expect([for (final c in server.received) (c as PractiseChange).note], ['first', 'second']);
    expect(queue.pending, isEmpty);
  });

  test('two flushes at once share one run, so nothing is sent twice', () async {
    final server = Server()..hold = Completer<void>();
    final queue = ChangeQueue(MapStore(), server.send);
    await queue.add(practise('brakes.pads'));
    final a = queue.flush();
    final b = queue.flush();
    server.hold!.complete();
    expect(await a, await b);
    expect(server.received, hasLength(1));
  });

  test('a queue written by a newer build is kept aside, not thrown away', () async {
    final store = MapStore()
      ..values['q'] = jsonEncode({
        'pending': [
          {'kind': 'photo'},
        ],
      });
    final queue = ChangeQueue(store, Server().send, key: 'q');
    await queue.load();
    expect(queue.pending, isEmpty);
    expect(store.values['q.unreadable'], isNotNull);
  });

  test('the screen shows a change before the server has it', () {
    final practised = practise('brakes.pads', note: 'Corolla').applyTo(null);
    expect(practised.status, SkillStatus.practised);
    final review = ReviewChange(
      id: newId(),
      workshopId: 'w1',
      traineeId: 't1',
      skillCode: 'brakes.pads',
      signedOff: true,
      note: '',
      at: DateTime.utc(2026, 11, 27, 10),
    );
    final signed = review.applyTo(practised)!;
    expect(signed.status, SkillStatus.signedOff);
    expect(practise('brakes.pads').applyTo(signed), signed, reason: 'practice never undoes a sign-off');
    expect(review.applyTo(null), isNull);
  });

  test('changes and records read back what they wrote', () {
    final c = practise('brakes.pads', note: 'n');
    expect(Change.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, Object?>).toJson(), c.toJson());
    final r = c.applyTo(null);
    expect(SkillRecord.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, Object?>), r);
    expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(newId()), isTrue);
  });

  test('the auto repair checklist has unique codes the database accepts, and Arabic for every line', () {
    const trade = Trade.autoRepair;
    final codes = [for (final s in trade.skills) s.code];
    expect(codes.toSet(), hasLength(codes.length));
    expect(codes, hasLength(32));
    for (final area in trade.areas) {
      expect(area.ar, isNotEmpty);
      for (final s in area.skills) {
        expect(s.code, matches(RegExp(r'^[a-z0-9_.]{2,60}$')));
        expect(s.code.startsWith('${area.code}.'), isTrue, reason: s.code);
        expect(RegExp('[؀-ۿ]').hasMatch(s.ar), isTrue, reason: s.code);
      }
    }
    expect(trade.skills.where((s) => s.safety), isNotEmpty);
  });

  group('jobs and shifts', () {
    final at = DateTime.utc(2026, 11, 27, 8);
    Job job({JobStatus status = JobStatus.assigned}) =>
        Job(id: 'j1', workshopId: 'w1', traineeId: 't1', title: 'Front pads', skillCodes: const ['brakes.pads'], status: status, assignedAt: at);

    test('a job shows given, done and checked before the server has it, and nothing undoes a check', () {
      final given = AssignJobChange(id: newId(), workshopId: 'w1', job: job(), at: at).applyTo(null);
      expect(given.status, JobStatus.assigned);
      final done = FinishJobChange(id: newId(), workshopId: 'w1', jobId: 'j1', minutes: 90, note: 'n', at: at).applyTo(given)!;
      expect((done.status, done.minutes), (JobStatus.done, 90));
      final checked = CheckJobChange(id: newId(), workshopId: 'w1', jobId: 'j1', minutes: 75, note: '', at: at).applyTo(done)!;
      expect((checked.status, checked.checkedMinutes, checked.minutes), (JobStatus.checked, 75, 90));
      expect(FinishJobChange(id: newId(), workshopId: 'w1', jobId: 'j1', minutes: 120, note: '', at: at).applyTo(checked), checked);
      expect(
        CancelJobChange(id: newId(), workshopId: 'w1', jobId: 'j1', at: at).applyTo(done),
        done,
        reason: 'a finished job cannot be called off',
      );
      expect(
        CheckJobChange(id: newId(), workshopId: 'w1', jobId: 'j1', minutes: 75, note: '', at: at).applyTo(given),
        given,
        reason: 'not finished yet',
      );
    });

    test('a shift opens, closes and is confirmed with corrected times; a confirmed one stays', () {
      final opened = CheckInChange(id: newId(), workshopId: 'w1', shiftId: 's1', traineeId: 't1', at: at).applyTo(null);
      expect(opened.open, isTrue);
      final closed = CheckOutChange(id: newId(), workshopId: 'w1', shiftId: 's1', at: at.add(const Duration(hours: 8))).applyTo(opened)!;
      expect(closed.length, const Duration(hours: 8));
      final confirmed = ConfirmShiftChange(
        id: newId(),
        workshopId: 'w1',
        shiftId: 's1',
        checkIn: at,
        checkOut: at.add(const Duration(hours: 7, minutes: 30)),
        at: at.add(const Duration(hours: 9)),
      ).applyTo(closed)!;
      expect((confirmed.confirmed, confirmed.length), (true, const Duration(hours: 7, minutes: 30)));
      expect(CheckOutChange(id: newId(), workshopId: 'w1', shiftId: 's1', at: at.add(const Duration(hours: 10))).applyTo(confirmed), confirmed);
    });

    test('hours count only what a supervisor confirmed, and say what waits', () {
      final shifts = [
        Shift(id: 'a', workshopId: 'w1', traineeId: 't1', checkIn: at, checkOut: at.add(const Duration(hours: 8)), confirmedAt: at),
        Shift(id: 'b', workshopId: 'w1', traineeId: 't1', checkIn: at, checkOut: at.add(const Duration(hours: 2))),
        Shift(id: 'c', workshopId: 'w1', traineeId: 't1', checkIn: at),
        Shift(id: 'd', workshopId: 'w1', traineeId: 'other', checkIn: at, checkOut: at.add(const Duration(hours: 5)), confirmedAt: at),
      ];
      final jobs = [
        job(status: JobStatus.checked).copyWith(minutes: 90, checkedMinutes: 60),
        job(status: JobStatus.done).copyWith(minutes: 30),
        job(status: JobStatus.cancelled).copyWith(minutes: 600),
      ];
      expect(
        Hours.of('t1', shifts, jobs),
        const Hours(workshop: Duration(hours: 8), workshopWaiting: Duration(hours: 2), handsOn: Duration(hours: 1), handsOnWaiting: Duration(minutes: 30)),
      );
    });

    test('job and shift changes read back what they wrote', () {
      final changes = <Change>[
        AssignJobChange(id: newId(), workshopId: 'w1', job: job(), at: at),
        FinishJobChange(id: newId(), workshopId: 'w1', jobId: 'j1', minutes: 45, note: 'n', at: at),
        CheckJobChange(id: newId(), workshopId: 'w1', jobId: 'j1', minutes: 30, note: 'm', at: at),
        CancelJobChange(id: newId(), workshopId: 'w1', jobId: 'j1', at: at),
        CheckInChange(id: newId(), workshopId: 'w1', shiftId: 's1', traineeId: 't1', at: at),
        CheckOutChange(id: newId(), workshopId: 'w1', shiftId: 's1', at: at),
        ConfirmShiftChange(id: newId(), workshopId: 'w1', shiftId: 's1', checkIn: at, checkOut: at.add(const Duration(hours: 1)), at: at),
      ];
      for (final c in changes) {
        expect(Change.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, Object?>).toJson(), c.toJson(), reason: c.target);
      }
      expect({for (final c in changes) c.target}, hasLength(changes.length), reason: 'each kind has its own target');
      final j = job(status: JobStatus.checked).copyWith(minutes: 90, checkedMinutes: 60, doneAt: at, checkedAt: at);
      expect(Job.fromJson(jsonDecode(jsonEncode(j.toJson())) as Map<String, Object?>), j);
      final s = Shift(id: 's1', workshopId: 'w1', traineeId: 't1', checkIn: at, checkOut: at.add(const Duration(hours: 1)), confirmedAt: at);
      expect(Shift.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>), s);
    });

    test('a check-in and check-out made with no signal go out in order, after it comes back', () async {
      final server = Server()..reachable = false;
      final queue = ChangeQueue(MapStore(), server.send);
      await queue.add(CheckInChange(id: newId(), workshopId: 'w1', shiftId: 's1', traineeId: 't1', at: at));
      await queue.add(CheckOutChange(id: newId(), workshopId: 'w1', shiftId: 's1', at: at.add(const Duration(hours: 8))));
      expect((await queue.flush()).offline, isTrue);
      server.reachable = true;
      expect(await queue.flush(), (sent: 2, rejected: 0, offline: false));
      expect([for (final c in server.received) c.runtimeType], [CheckInChange, CheckOutChange]);
    });
  });
}
