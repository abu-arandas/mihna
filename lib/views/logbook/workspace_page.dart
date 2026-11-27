import 'dart:async';

import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../../controllers/logbook_controller.dart';
import '../../controllers/session_controller.dart';
import '../../controllers/workshop_controller.dart';
import '../../models/membership.dart';
import '../../models/role.dart';
import '../../widgets/language_button.dart';
import '../../widgets/sync_badge.dart';
import '../work/hours_page.dart';
import '../work/jobs_board.dart';
import '../work/today_page.dart';
import 'people_page.dart';
import 'review_queue.dart';
import 'skill_checklist.dart';
import 'trainee_list.dart';

/// The workshop, as the person's role sees it. A trainee gets their day (check-in and jobs), their checklist and
/// their hours. A supervisor gets what waits for them, the jobs and the trainees; an admin also gets the people.
class WorkspacePage extends StatefulWidget {
  const WorkspacePage({required this.membership, super.key});

  final Membership membership;

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  var _tab = 0;

  @override
  void initState() {
    super.initState();
    unawaited(Get.find<LogbookController>().open(widget.membership));
    if (widget.membership.role.reviews) unawaited(Get.find<WorkshopController>().loadMembers());
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.membership;
    final tabs = <(IconData, String, Widget)>[
      if (m.role == Role.trainee) ...[
        (Icons.today_outlined, 'Today', TodayPage(me: m)),
        (Icons.checklist, 'My skills', SkillChecklist(traineeId: m.userId, traineeName: m.displayName, reviewer: false)),
        (Icons.schedule, 'Hours', HoursPage(traineeId: m.userId, traineeName: m.displayName, supervisor: false)),
      ],
      if (m.role.reviews) ...[
        (Icons.task_alt, 'To sign off', const ReviewQueue()),
        (Icons.build_circle_outlined, 'Jobs', const JobsBoard()),
        (Icons.groups_outlined, 'Trainees', const TraineeList()),
      ],
      if (m.role == Role.admin) (Icons.manage_accounts_outlined, 'People', const PeoplePage()),
    ];
    final tab = _tab.clamp(0, tabs.length - 1);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.workshopName),
            Text(
              m.role == Role.trainee ? 'Trainee'.tr : (m.role == Role.supervisor ? 'Supervisor'.tr : 'Admin'.tr),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          const SyncBadge(),
          const LanguageButton(),
          IconButton(tooltip: 'Sign out'.tr, icon: const Icon(Icons.logout), onPressed: Get.find<SessionController>().signOut),
        ],
      ),
      body: tabs[tab].$3,
      bottomNavigationBar: tabs.length < 2
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: [for (final t in tabs) NavigationDestination(icon: Icon(t.$1), label: t.$2.tr)],
            ),
    );
  }
}
