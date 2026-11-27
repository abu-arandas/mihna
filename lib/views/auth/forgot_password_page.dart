import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../../controllers/session_controller.dart';
import '../../widgets/motion.dart';
import 'auth_frame.dart';

/// Asks for an email and sends a link to choose a new password. The link opens the app on the new-password page
/// (see Home).
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await Get.find<SessionController>().sendPasswordReset(_email.text);
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
          heading: 'Reset your password'.tr,
          intro: "Enter your account's email and we will send you a link to choose a new password.".tr,
          fields: [
            TextFormField(
              key: const Key('email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(labelText: 'Email'.tr),
              validator: AuthChecks.email,
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
          actions: [
            PressScale(
              child: Obx(() => FilledButton(onPressed: session.busy.value ? null : _submit, child: Text('Send the link'.tr))),
            ),
            TextButton(onPressed: AuthFrame.backToSignIn, child: Text('Back to sign in'.tr)),
          ],
        ),
      ),
    );
  }
}
