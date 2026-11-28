import 'dart:async';

import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/breakpoints.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../controllers/session_controller.dart';
import '../../widgets/language_button.dart';
import '../../widgets/motion.dart';
import '../../widgets/stitch_line.dart';

/// The shared page of the ways in (sign-in, sign-up, forgot and new password): a heading with the stitch sewing
/// itself under it, the fields and buttons settling in a step at a time, and the session's last error or notice.
/// With reduce motion on, it is simply all there.
class AuthFrame extends StatelessWidget {
  const AuthFrame({required this.formKey, required this.heading, required this.fields, required this.actions, this.intro, super.key});

  final GlobalKey<FormState> formKey;

  /// Already translated.
  final String heading;

  /// A line under the heading, already translated.
  final String? intro;

  final List<Widget> fields;

  /// The main button first, then any links.
  final List<Widget> actions;

  /// Back to the sign-in page: the page underneath, or Home when this page was opened from its own address.
  static void backToSignIn() {
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back<void>();
    } else {
      unawaited(Get.offAllNamed<void>(Routes.home));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = Get.find<SessionController>();
    var step = 2;
    Widget next(Widget child) => Appear(delay: AppTheme.stagger * step++, child: child);
    return Scaffold(
      appBar: AppBar(actions: const [LanguageButton()]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: GridContainer(
          child: GridRow(
            children: [
              GridCol(
                md: 8,
                lg: 6,
                child: Form(
                  key: formKey,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Appear(
                          child: Semantics(header: true, child: Text(heading, style: theme.textTheme.headlineMedium)),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: SewIn(delay: AppTheme.stagger * 3, child: const StitchLine()),
                        ),
                        if (intro case final intro?) ...[
                          const SizedBox(height: 16),
                          Appear(
                            delay: AppTheme.stagger,
                            child: Text(intro, style: TextStyle(color: theme.colorScheme.outline)),
                          ),
                        ],
                        const SizedBox(height: 28),
                        for (final (i, field) in fields.indexed) ...[if (i > 0) const SizedBox(height: 12), next(field)],
                        const SizedBox(height: 20),
                        for (final (i, action) in actions.indexed) ...[if (i > 0) const SizedBox(height: 8), next(action)],
                        Obx(() {
                          final error = session.error.value;
                          final notice = session.notice.value;
                          if (error == null && notice == null) return const SizedBox.shrink();
                          // A problem stays plain: it slides in, no joke. Good news is calm too.
                          final text = (error ?? notice)!;
                          return Appear(
                            key: ValueKey(text),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(text.tr, style: TextStyle(color: error != null ? theme.colorScheme.error : theme.colorScheme.primary)),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The checks the forms share. Their messages are English keys, translated here.
abstract final class AuthChecks {
  /// The shortest password the forms accept. Neon Auth's own minimum (8 by default) should be the same or lower, or
  /// its message shows instead.
  static const minPasswordLength = 8;

  static String? required(String? value) => (value ?? '').trim().isEmpty ? 'Required'.tr : null;

  static String? email(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Required'.tr;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text) ? null : 'Enter a valid email'.tr;
  }

  static String? newPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Required'.tr;
    return text.length < minPasswordLength ? 'Use at least @count characters'.trParams({'count': '$minPasswordLength'}) : null;
  }

  /// Checks a "confirm password" field against [password].
  static FormFieldValidator<String> sameAs(TextEditingController password) =>
      (value) => (value ?? '').isEmpty ? 'Required'.tr : (value == password.text ? null : 'The passwords do not match'.tr);
}
