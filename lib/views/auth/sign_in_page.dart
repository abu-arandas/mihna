import 'dart:async';

import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/brand.dart';
import '../../config/routes.dart';
import '../../controllers/session_controller.dart';
import '../../widgets/motion.dart';
import 'auth_frame.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await Get.find<SessionController>().signIn(_email.text, _password.text);
  }

  /// Opens one of the other ways in, and comes back to a page without its messages.
  Future<void> _open(String route) async {
    final session = Get.find<SessionController>()..clearMessages();
    await Get.toNamed<void>(route);
    session.clearMessages();
  }

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionController>();
    return AuthFrame(
      formKey: _form,
      heading: Brand.name.tr,
      fields: [
        TextFormField(
          key: const Key('email'),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(labelText: 'Email'.tr),
          validator: AuthChecks.required,
        ),
        TextFormField(
          key: const Key('password'),
          controller: _password,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(labelText: 'Password'.tr),
          validator: AuthChecks.required,
          onFieldSubmitted: (_) => _submit(),
        ),
      ],
      actions: [
        PressScale(
          child: Obx(() => FilledButton(onPressed: session.busy.value ? null : _submit, child: Text('Sign in'.tr))),
        ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(key: const Key('forgot-password'), onPressed: () => unawaited(_open(Routes.forgotPassword)), child: Text('Forgot your password?'.tr)),
            if (Brand.allowSignUp) TextButton(key: const Key('sign-up'), onPressed: () => unawaited(_open(Routes.signUp)), child: Text('Create an account'.tr)),
          ],
        ),
      ],
    );
  }
}
