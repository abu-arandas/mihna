import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../../controllers/workshop_controller.dart';
import '../logbook/workspace_page.dart';
import 'start_workshop_page.dart';

/// After sign-in: the person's workshop, or a way to start one when they are in none yet.
class WorkshopGate extends StatelessWidget {
  const WorkshopGate({super.key});

  @override
  Widget build(BuildContext context) {
    final workshops = Get.find<WorkshopController>();
    return Obx(() {
      final current = workshops.current.value;
      if (current != null) return WorkspacePage(key: ValueKey('${current.workshopId}/${current.userId}'), membership: current);
      if (workshops.loading.value) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      return const StartWorkshopPage();
    });
  }
}
