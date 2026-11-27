import 'dart:async';

import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/breakpoints.dart';
import '../../config/theme.dart';
import '../../controllers/session_controller.dart';
import '../../controllers/workshop_controller.dart';
import '../../services/auth_service.dart';
import '../../widgets/language_button.dart';
import '../../widgets/motion.dart';
import '../../widgets/stitch_line.dart';

/// Someone signed in who is in no workshop yet: a trainee or supervisor waits to be added, and the person running the
/// workshop starts its logbook here.
class StartWorkshopPage extends StatefulWidget {
  const StartWorkshopPage({super.key});

  @override
  State<StartWorkshopPage> createState() => _StartWorkshopPageState();
}

class _StartWorkshopPageState extends State<StartWorkshopPage> {
  final _workshop = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _workshop.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workshops = Get.find<WorkshopController>();
    final email = Get.find<AuthService>().email ?? '';
    var step = 0;
    Widget next(Widget child) => Appear(delay: AppTheme.stagger * step++, child: child);
    return Scaffold(
      appBar: AppBar(
        actions: [
          const LanguageButton(),
          IconButton(tooltip: 'Sign out'.tr, icon: const Icon(Icons.logout), onPressed: Get.find<SessionController>().signOut),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: workshops.load,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          children: [
            GridContainer(
              child: GridRow(
                children: [
                  GridCol(
                    md: 8,
                    lg: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        next(Text('Joining a workshop?'.tr, style: theme.textTheme.headlineSmall)),
                        const SizedBox(height: 8),
                        const SewIn(child: StitchLine()),
                        const SizedBox(height: 12),
                        next(Text('Ask the workshop admin to add you with this email. Then pull down to refresh.'.tr, style: theme.textTheme.bodyLarge)),
                        const SizedBox(height: 8),
                        next(SelectableText(email, style: theme.textTheme.titleMedium)),
                        const SizedBox(height: 40),
                        next(Text('Running a workshop?'.tr, style: theme.textTheme.titleLarge)),
                        const SizedBox(height: 8),
                        next(Text('Start its logbook. You become its admin and add your trainees and supervisors.'.tr)),
                        const SizedBox(height: 16),
                        next(
                          TextField(
                            key: const Key('workshop-name'),
                            controller: _workshop,
                            decoration: InputDecoration(labelText: 'Workshop name'.tr),
                          ),
                        ),
                        const SizedBox(height: 12),
                        next(
                          TextField(
                            key: const Key('your-name'),
                            controller: _name,
                            decoration: InputDecoration(labelText: 'Your name'.tr),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Obx(() {
                          final error = workshops.error.value;
                          return error == null
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(error.tr, style: TextStyle(color: theme.colorScheme.error)),
                                );
                        }),
                        next(
                          PressScale(
                            child: Obx(
                              () => FilledButton(
                                onPressed: workshops.busy.value ? null : () => unawaited(workshops.startWorkshop(_workshop.text, _name.text)),
                                child: Text('Start the logbook'.tr),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
