import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';

import '../models/membership.dart';
import '../models/role.dart';
import '../services/change_queue.dart';
import '../services/local_store.dart';
import '../services/workshop_service.dart';
import 'session_controller.dart';

/// Which workshop the signed-in person is in, their role there, and (for an admin) its people.
///
/// The person's workshops are kept on the phone, so the app opens on the right page with no signal.
class WorkshopController extends GetxController {
  WorkshopController(this._service, this._store, this._session);

  final WorkshopService _service;
  final LocalStore _store;
  final SessionController _session;

  final memberships = <Membership>[].obs;
  final current = Rxn<Membership>();
  final members = <Membership>[].obs;

  /// True until the first answer, from the phone or the server.
  final loading = true.obs;
  final busy = false.obs;
  final error = RxnString();
  final notice = RxnString();

  StreamSubscription<String?>? _user;

  String? get _uid => _session.userId.value;
  String get _cacheKey => 'mihna.memberships.$_uid';

  @override
  void onInit() {
    super.onInit();
    _user = _session.userId.listen((_) => unawaited(load()));
    unawaited(load());
  }

  @override
  void onClose() {
    unawaited(_user?.cancel());
    super.onClose();
  }

  /// The phone's copy first, then the server's.
  Future<void> load() async {
    final uid = _uid;
    memberships.clear();
    members.clear();
    current.value = null;
    if (uid == null) return;
    loading.value = true;
    error.value = null;
    try {
      final saved = await _store.read(_cacheKey);
      if (saved != null) _show([for (final m in jsonDecode(saved) as List<Object?>) Membership.fromJson(m! as Map<String, Object?>)]);
    } on Object {
      // A copy this build cannot read: the server's answer replaces it.
    }
    if (memberships.isNotEmpty) loading.value = false;
    try {
      final fresh = await _service.myMemberships(uid);
      if (_uid != uid) return;
      _show(fresh);
      await _store.write(_cacheKey, jsonEncode([for (final m in fresh) m.toJson()]));
    } on Object {
      if (memberships.isEmpty) error.value = 'Could not reach the server. Check the connection and try again.';
    } finally {
      loading.value = false;
    }
  }

  void _show(List<Membership> list) {
    memberships.assignAll(list);
    final keep = list.where((m) => m.workshopId == current.value?.workshopId).firstOrNull;
    current.value = keep ?? list.firstOrNull;
  }

  void choose(Membership membership) => current.value = membership;

  /// Starts a workshop, with the signed-in person as its admin.
  Future<bool> startWorkshop(String name, String displayName) async {
    if (name.trim().isEmpty || displayName.trim().isEmpty) {
      error.value = 'Fill in both names.';
      return false;
    }
    return _attempt(() async {
      await _service.startWorkshop(name: name.trim(), displayName: displayName.trim());
      await load();
    });
  }

  Future<void> loadMembers() async {
    final ws = current.value;
    if (ws == null) return;
    try {
      members.assignAll(await _service.members(ws.workshopId));
    } on Object {
      error.value = 'Could not reach the server. Check the connection and try again.';
    }
  }

  /// The trainees of the current workshop, from the last [loadMembers].
  List<Membership> get trainees => members.where((m) => m.role == Role.trainee).toList();

  String nameOf(String userId) => members.where((m) => m.userId == userId).firstOrNull?.displayName ?? '';

  Future<bool> addMember(String email, Role role, String displayName) async {
    final ws = current.value;
    if (ws == null) return false;
    if (!email.contains('@') || displayName.trim().isEmpty) {
      error.value = 'Enter their email and name.';
      return false;
    }
    return _attempt(() async {
      await _service.addMember(workshopId: ws.workshopId, email: email.trim(), role: role, displayName: displayName.trim());
      await loadMembers();
      notice.value = 'Added. They see this workshop the next time they open Mihna.';
    });
  }

  Future<bool> removeMember(Membership member) => _attempt(() async {
    await _service.removeMember(workshopId: member.workshopId, userId: member.userId);
    await loadMembers();
  });

  Future<bool> _attempt(Future<void> Function() call) async {
    busy.value = true;
    error.value = null;
    notice.value = null;
    try {
      await call();
      return true;
    } on RejectedChange catch (e) {
      error.value = e.message;
    } on Object {
      error.value = 'Could not reach the server. Check the connection and try again.';
    } finally {
      busy.value = false;
    }
    return false;
  }
}
