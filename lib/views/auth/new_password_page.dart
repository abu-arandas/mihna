import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../../controllers/session_controller.dart';
import '../../widgets/motion.dart';
import 'auth_frame.dart';

/// Shown by Home after a password-reset link opens the app: the person is signed in only to choose a new password.
/// Saving it takes them into the app.
class NewPasswordPage extends StatefulWidget {
  const NewPasswordPage({super.key});

  @override
  State<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<NewPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    // Taken before the wait: once the password is saved, Home swaps this page for the app.
    final messenger = ScaffoldMessenger.of(context);
    final saved = await Get.find<SessionController>().updatePassword(_password.text);
    if (saved) messenger.showSnackBar(SnackBar(content: Text('Your new password is saved.'.tr)));
  }

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionController>();
    return AuthFrame(
      formKey: _form,
      heading: 'Choose a new password'.tr,
      fields: [
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
        TextButton(onPressed: session.signOut, child: Text('Sign out'.tr)),
      ],
    );
  }
}
