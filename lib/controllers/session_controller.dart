import 'dart:async';

import 'package:get/get.dart';

import '../config/brand.dart';
import '../services/auth_service.dart';

/// Who is signed in, how they got in (sign-in, sign-up, a reset link), and which language the app speaks.
class SessionController extends GetxController {
  SessionController(this._auth, {this.redirectTo});

  final AuthService _auth;

  /// Where the links in sign-up and reset emails open; null for the Supabase project's Site URL.
  final String? redirectTo;

  StreamSubscription<String?>? _changes;
  StreamSubscription<void>? _recoveries;

  late final userId = RxnString(_auth.userId);
  final locale = Brand.locales.first.obs;
  final busy = false.obs;

  /// True between opening a password-reset link and choosing the new password.
  final recovering = false.obs;

  /// The last attempt's failure, ready to show; null when there is none.
  final error = RxnString();

  /// The last attempt's good news, such as "check your email"; null when there is none.
  final notice = RxnString();

  bool get signedIn => userId.value != null;

  @override
  void onInit() {
    super.onInit();
    _changes = _auth.userChanges.listen((id) {
      userId.value = id;
      if (id == null) recovering.value = false;
    });
    _recoveries = _auth.passwordRecoveries.listen((_) => recovering.value = true);
  }

  @override
  void onClose() {
    unawaited(_changes?.cancel());
    unawaited(_recoveries?.cancel());
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
      signedInNow = await _auth.signUp(email: email, password: password, redirectTo: redirectTo);
      if (signedInNow) {
        userId.value = _auth.userId;
      } else {
        notice.value = 'Check your email for a link to confirm your account, then sign in.';
      }
    });
    return signedInNow;
  }

  /// Sends a reset link. The notice is the same whether or not the email has an account.
  Future<void> sendPasswordReset(String email) => _attempt(() async {
    await _auth.sendPasswordReset(email: email, redirectTo: redirectTo);
    notice.value = 'If that email has an account, a link to choose a new password is on its way.';
  });

  /// Saves the new password chosen after a reset link. Returns true when it was saved.
  Future<bool> updatePassword(String password) async {
    var saved = false;
    await _attempt(() async {
      await _auth.updatePassword(password);
      recovering.value = false;
      saved = true;
    });
    return saved;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    userId.value = null;
    recovering.value = false;
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
