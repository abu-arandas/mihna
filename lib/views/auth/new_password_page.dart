import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/routes.dart';
import '../../controllers/session_controller.dart';
import '../../widgets/motion.dart';
import 'auth_frame.dart';

/// Opened after "Forgot your password?" sends a code: the person types the code from their email and a new
/// password. Saving it signs them in and takes them into the app.
class NewPasswordPage extends StatefulWidget {
  const NewPasswordPage({super.key, this.email});

  /// The email the code went to, filled in for them.
  final String? email;

  @override
  State<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<NewPasswordPage> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email ?? '');
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    // Taken before the wait: once the password is saved, the app opens in place of this page.
    final messenger = ScaffoldMessenger.of(context);
    final saved = await Get.find<SessionController>().resetPassword(_email.text, _code.text, _password.text);
    if (!saved) return;
    messenger.showSnackBar(SnackBar(content: Text('Your new password is saved.'.tr)));
    await Get.offAllNamed<void>(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionController>();
    // Pushed over Home, so it builds itself again when the language changes.
    return Obx(
      () => KeyedSubtree(
        key: ValueKey(session.locale.value),
        child: AuthFrame(
          formKey: _form,
          heading: 'Choose a new password'.tr,
          intro: 'Type the code from your email and a new password.'.tr,
          fields: [
            TextFormField(
              key: const Key('email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(labelText: 'Email'.tr),
              validator: AuthChecks.email,
            ),
            TextFormField(
              key: const Key('code'),
              controller: _code,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              decoration: InputDecoration(labelText: 'Code from the email'.tr),
              validator: AuthChecks.required,
            ),
            TextFormField(
              key: const Key('password'),
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'New password'.tr,
                helperText: 'At least @count characters'.trParams({'count': '${AuthChecks.minPasswordLength}'}),
              ),
              validator: AuthChecks.newPassword,
            ),
            TextFormField(
              key: const Key('confirm-password'),
              controller: _confirm,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(labelText: 'Confirm password'.tr),
              validator: AuthChecks.sameAs(_password),
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
          actions: [
            PressScale(
              child: Obx(() => FilledButton(onPressed: session.busy.value ? null : _submit, child: Text('Save password'.tr))),
            ),
            TextButton(onPressed: () => Get.offAllNamed<void>(Routes.home), child: Text('Back to sign in'.tr)),
          ],
        ),
      ),
    );
  }
}
