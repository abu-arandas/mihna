import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../controllers/session_controller.dart';

/// Switches the app between Arabic and English. Its label names the language it switches to.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) => TextButton(onPressed: () => Get.find<SessionController>().toggleLanguage(), child: Text('العربية'.tr));
}
