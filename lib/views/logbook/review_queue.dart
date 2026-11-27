import 'dart:async';

import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/brand.dart';
import '../../config/breakpoints.dart';
import '../../config/theme.dart';
import '../../controllers/logbook_controller.dart';
import '../../controllers/workshop_controller.dart';
import '../../models/skill_record.dart';
import '../../models/trade.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fun.dart';
import '../../widgets/motion.dart';
import 'skill_sheet.dart';
import 'skill_status.dart';

/// Everything the workshop's trainees logged that waits for a supervisor, oldest first.
class ReviewQueue extends StatefulWidget {
  const ReviewQueue({super.key});

  @override
  State<ReviewQueue> createState() => _ReviewQueueState();
}

class _ReviewQueueState extends State<ReviewQueue> {
  /// Rows already shown, so a row settles in once and not each time the lazy list builds it.
  final _seen = <String>{};

  @override
  Widget build(BuildContext context) {
    final logbook = Get.find<LogbookController>();
    final workshops = Get.find<WorkshopController>();
    final trade = Trade.all[Brand.trade]!;
    final language = Get.locale?.languageCode ?? 'ar';
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([logbook.sync(), workshops.loadMembers()]);
      },
      child: Obx(() {
        final waiting = logbook.records.values.where((r) => r.status == SkillStatus.practised && trade.skill(r.skillCode) != null).toList()
          ..sort((a, b) => a.practisedAt.compareTo(b.practisedAt));
        if (waiting.isEmpty) {
          return ListView(
            children: [
              EmptyState(
                icon: Icons.task_alt,
                title: funLine(['Nothing waiting. Time for a tea.'.tr, 'All caught up. The lift is free.'.tr]),
                message: 'When a trainee logs practice, it shows here for you to sign off.',
              ),
            ],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: waiting.length,
          itemBuilder: (context, i) {
            final r = waiting[i];
            final skill = trade.skill(r.skillCode)!;
            final name = workshops.nameOf(r.traineeId);
            final tile = GridContainer(
              child: ListTile(
                shape: AppTheme.shape(14),
                leading: CircleAvatar(child: Text(name.isEmpty ? '?' : name.characters.first)),
                title: Text(skill.title(language)),
                subtitle: Text(
                  [name, whenText(context, r.practisedAt), if (r.note.isNotEmpty) r.note].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                ),
                trailing: skill.safety ? SafetyTag(compact: context.isMobile) : const Icon(Icons.chevron_right),
                onTap: () => unawaited(openSkillSheet(context, skill: skill, traineeId: r.traineeId, traineeName: name, reviewer: true)),
              ),
            );
            if (!_seen.add(r.key)) return tile;
            return Appear(key: ValueKey(r.key), delay: AppTheme.stagger * i.clamp(0, 8), child: tile);
          },
        );
      }),
    );
  }
}
