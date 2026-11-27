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
import '../work/hours_page.dart';
import '../work/jobs_board.dart';
import '../work/work_bits.dart';
import 'skill_checklist.dart';

/// The workshop's trainees, how far each is and their confirmed hours. Opening one shows their checklist, jobs and
/// hours, to sign off, give jobs and confirm shifts from.
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
            final hours = logbook.hoursOf(t.userId);
            final inside = logbook.openShiftOf(t.userId) != null;
            return GridContainer(
              child: ListTile(
                shape: AppTheme.shape(14),
                leading: Badge(
                  isLabelVisible: inside,
                  smallSize: 10,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: CircleAvatar(child: Text(t.displayName.characters.first)),
                ),
                title: Text(t.displayName),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(value: signed / total, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                          ),
                          const SizedBox(width: 10),
                          Text('$signed/$total', style: const TextStyle(fontFeatures: figures)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          '@time in the workshop'.trParams({'time': hoursText(hours.workshop)}),
                          '@time hands-on'.trParams({'time': hoursText(hours.handsOn)}),
                          if (inside) 'In now'.tr,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFeatures: figures),
                      ),
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
      builder: (context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Text(t.displayName),
            actions: const [SyncBadge()],
            bottom: TabBar(
              tabs: [
                Tab(text: 'Skills'.tr),
                Tab(text: 'Jobs'.tr),
                Tab(text: 'Hours'.tr),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              SkillChecklist(traineeId: t.userId, traineeName: t.displayName, reviewer: true),
              JobsBoard(traineeId: t.userId),
              HoursPage(traineeId: t.userId, traineeName: t.displayName, supervisor: true),
            ],
          ),
        ),
      ),
    ),
  );
}
