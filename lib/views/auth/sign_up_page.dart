import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/routes.dart';
import '../../controllers/session_controller.dart';
import '../../widgets/motion.dart';
import 'auth_frame.dart';

/// A new account with an email and password. When the Supabase project confirms emails, the person is told to
/// check their inbox; otherwise they are signed in and taken into the app.
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final signedIn = await Get.find<SessionController>().signUp(_email.text, _password.text);
    if (signedIn) await Get.offAllNamed<void>(Routes.home);
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
          heading: 'Create an account'.tr,
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
              key: const Key('password'),
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Password'.tr,
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
              child: Obx(() => FilledButton(onPressed: session.busy.value ? null : _submit, child: Text('Create account'.tr))),
            ),
            TextButton(onPressed: AuthFrame.backToSignIn, child: Text('I already have an account'.tr)),
          ],
        ),
      ),
    );
  }
}
