import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../config/routes.dart';
import '../config/theme.dart';
import '../widgets/fun.dart';
import '../widgets/language_button.dart';
import '../widgets/motion.dart';

/// Any address the app does not know: a lost wheel nut rolls in, a light line, and the way back.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(actions: const [LanguageButton()]),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LostNut(label: 'The lost nut'.tr),
              const SizedBox(height: 24),
              Appear(
                delay: AppTheme.slow,
                child: Semantics(
                  header: true,
                  child: Text(
                    funLine(['This page rolled under the car.'.tr, 'This page went out for a coffee.'.tr]),
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Appear(
                delay: AppTheme.slow + AppTheme.stagger * 2,
                child: Text(
                  'The page you asked for is not here.'.tr,
                  style: TextStyle(color: theme.colorScheme.outline),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Appear(
                delay: AppTheme.slow + AppTheme.stagger * 4,
                child: PressScale(
                  child: FilledButton(onPressed: () => Get.offAllNamed<void>(Routes.home), child: Text('Back to the start'.tr)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
