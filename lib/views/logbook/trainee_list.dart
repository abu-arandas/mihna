import 'dart:async';

import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/brand.dart';
import '../../config/breakpoints.dart';
import '../../config/theme.dart';
import '../../controllers/logbook_controller.dart';
import '../../controllers/workshop_controller.dart';
import '../../models/membership.dart';
import '../../models/skill_record.dart';
import '../../models/trade.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/sync_badge.dart';
import 'skill_checklist.dart';

/// The workshop's trainees and how far each is. Opening one shows their checklist, to sign off from.
class TraineeList extends StatelessWidget {
  const TraineeList({super.key});

  @override
  Widget build(BuildContext context) {
    final workshops = Get.find<WorkshopController>();
    final logbook = Get.find<LogbookController>();
    final trade = Trade.all[Brand.trade]!;
    final total = trade.skills.length;
    return RefreshIndicator(
      onRefresh: workshops.loadMembers,
      child: Obx(() {
        final trainees = workshops.trainees;
        if (trainees.isEmpty) {
          return ListView(
            children: const [EmptyState(icon: Icons.groups_outlined, title: 'No trainees yet', message: 'An admin adds them under People.')],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: trainees.length,
          itemBuilder: (context, i) {
            final t = trainees[i];
            final signed = trade.skills.where((s) => logbook.recordOf(t.userId, s.code)?.status == SkillStatus.signedOff).length;
            return GridContainer(
              child: ListTile(
                shape: AppTheme.shape(14),
                leading: CircleAvatar(child: Text(t.displayName.characters.first)),
                title: Text(t.displayName),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(value: signed / total, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(width: 10),
                      Text('$signed/$total', style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
                    ],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => unawaited(_open(context, t)),
              ),
            );
          },
        );
      }),
    );
  }

  Future<void> _open(BuildContext context, Membership t) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: Text(t.displayName), actions: const [SyncBadge()]),
        body: SkillChecklist(traineeId: t.userId, traineeName: t.displayName, reviewer: true),
      ),
    ),
  );
}
