import 'dart:async';

import 'package:get/get.dart';

import '../config/brand.dart';
import '../services/auth_service.dart';

/// Who is signed in, how they got in (sign-in, sign-up, a reset code), and which language the app speaks.
class SessionController extends GetxController {
  SessionController(this._auth);

  final AuthService _auth;

  StreamSubscription<String?>? _changes;

  late final userId = RxnString(_auth.userId);
  final locale = Brand.locales.first.obs;
  final busy = false.obs;

  /// The last attempt's failure, ready to show; null when there is none.
  final error = RxnString();

  /// The last attempt's good news, such as "check your email"; null when there is none.
  final notice = RxnString();

  bool get signedIn => userId.value != null;

  @override
  void onInit() {
    super.onInit();
    _changes = _auth.userChanges.listen((id) => userId.value = id);
  }

  @override
  void onClose() {
    unawaited(_changes?.cancel());
    super.onClose();
  }

  /// Clears the last error and notice, so a page opens without another page's message.
  void clearMessages() {
    error.value = null;
    notice.value = null;
  }

  Future<void> signIn(String email, String password) => _attempt(() async {
    await _auth.signIn(email: email, password: password);
    userId.value = _auth.userId;
  });

  /// Creates an account. Returns true when the person is signed in at once; otherwise [notice] asks them to
  /// confirm their email.
  Future<bool> signUp(String email, String password) async {
    var signedInNow = false;
    await _attempt(() async {
      signedInNow = await _auth.signUp(email: email, password: password);
      if (signedInNow) {
        userId.value = _auth.userId;
      } else {
        notice.value = 'Check your email for a link to confirm your account, then sign in.';
      }
    });
    return signedInNow;
  }

  /// Emails a reset code. Returns true when it went out; the notice is the same whether or not the email has an
  /// account.
  Future<bool> sendPasswordReset(String email) async {
    var sent = false;
    await _attempt(() async {
      await _auth.sendPasswordReset(email: email);
      notice.value = 'If that email has an account, a code to choose a new password is on its way.';
      sent = true;
    });
    return sent;
  }

  /// Saves a new password with the emailed code and signs in with it. Returns true when it was saved.
  Future<bool> resetPassword(String email, String code, String password) async {
    var saved = false;
    await _attempt(() async {
      await _auth.resetPassword(email: email, code: code, password: password);
      userId.value = _auth.userId;
      saved = true;
    });
    return saved;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    userId.value = null;
  }

  /// Runs [call] with [busy] on, turning any failure into [error] (rule 9: nothing a person does crashes a page).
  Future<void> _attempt(Future<void> Function() call) async {
    busy.value = true;
    clearMessages();
    try {
      await call();
    } on AuthFailure catch (e) {
      error.value = e.message;
    } catch (_) {
      error.value = 'Something went wrong. Try again.';
    } finally {
      busy.value = false;
    }
  }

  /// Switches between the languages in [Brand.locales]. The app rebuilds in place (see Home) rather than through
  /// `Get.updateLocale`, which reassembles the whole widget tree.
  void toggleLanguage() {
    final next = Brand.locales[(Brand.locales.indexOf(locale.value) + 1) % Brand.locales.length];
    Get.locale = next;
    locale.value = next;
    Get.rootController.update();
  }
}
