import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../controllers/session_controller.dart';
import '../views/auth/forgot_password_page.dart';
import '../views/auth/new_password_page.dart';
import '../views/auth/sign_up_page.dart';
import '../views/home.dart';
import 'brand.dart';

/// Every page the app can open by name.
class Routes {
  static const home = '/';
  static const signUp = '/sign-up';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
}

final appPages = [
  GetPage<void>(name: Routes.home, page: () => const Home()),
  // Without sign-up the address is unknown, so it opens the not-found page.
  if (Brand.allowSignUp) GetPage<void>(name: Routes.signUp, page: () => const SignUpPage(), middlewares: [SignedOutOnly()]),
  GetPage<void>(name: Routes.forgotPassword, page: () => const ForgotPasswordPage(), middlewares: [SignedOutOnly()]),
  GetPage<void>(
    name: Routes.resetPassword,
    page: () => NewPasswordPage(email: Get.arguments as String?),
    middlewares: [SignedOutOnly()],
  ),
];

/// Sends someone already signed in to the app instead of a page for getting in.
class SignedOutOnly extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) => Get.find<SessionController>().signedIn ? const RouteSettings(name: Routes.home) : null;
}
