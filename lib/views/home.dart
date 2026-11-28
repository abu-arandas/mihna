import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../config/routes.dart';
import '../controllers/session_controller.dart';
import 'auth/sign_in_page.dart';
import 'not_found_page.dart';
import 'workshop/workshop_gate.dart';

/// Signed-out people see sign-in, and everyone else sees the app. A change of language builds the page again, so
/// every `.tr` text is read in the new language.
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    // GetX opens the nearest known parent for an address it does not know, so `/nowhere` lands here on `/`. Anything
    // but `/` itself is the not-found page.
    final name = ModalRoute.of(context)?.settings.name;
    if (name != null && Uri.parse(name).path != Routes.home) return const NotFoundPage();
    final session = Get.find<SessionController>();
    return Obx(() => KeyedSubtree(key: ValueKey(session.locale.value), child: session.signedIn ? const WorkshopGate() : const SignInPage()));
  }
}
