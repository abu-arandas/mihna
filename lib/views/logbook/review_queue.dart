import 'dart:async';

import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/brand.dart';
import '../../config/breakpoints.dart';
import '../../config/theme.dart';
import '../../controllers/logbook_controller.dart';
import '../../controllers/workshop_controller.dart';
import '../../models/job.dart';
import '../../models/skill_record.dart';
import '../../models/trade.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fun.dart';
import '../../widgets/motion.dart';
import '../work/job_sheet.dart';
import '../work/shift_sheet.dart';
import '../work/today_page.dart';
import '../work/work_bits.dart';
import 'skill_sheet.dart';
import 'skill_status.dart';

/// Everything the workshop's trainees did that waits for a supervisor, oldest first: finished jobs to check, shifts
/// to confirm, and skills to sign off.
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
        final jobs = logbook.jobs.values.where((j) => j.status == JobStatus.done).toList()..sort((a, b) => a.assignedAt.compareTo(b.assignedAt));
        // Closed shifts, and open ones long past a working day (a check-out forgotten).
        final now = DateTime.now();
        final shifts = logbook.shifts.values.where((s) => !s.confirmed && (!s.open || now.difference(s.checkIn) > const Duration(hours: 16))).toList()
          ..sort((a, b) => a.checkIn.compareTo(b.checkIn));
        if (waiting.isEmpty && jobs.isEmpty && shifts.isEmpty) {
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
        return CustomScrollView(
          slivers: [
            if (jobs.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: GridContainer(child: SectionTitle('Jobs to check', count: jobs.length)),
              ),
              SliverList.builder(
                itemCount: jobs.length,
                itemBuilder: (context, i) {
                  final j = jobs[i];
                  final name = workshops.nameOf(j.traineeId);
                  return JobTile(
                    job: j,
                    traineeName: name,
                    onTap: () => unawaited(openJobSheet(context, jobId: j.id, traineeName: name, supervisor: true)),
                  );
                },
              ),
            ],
            if (shifts.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: GridContainer(child: SectionTitle('Shifts to confirm', count: shifts.length)),
              ),
              SliverList.builder(
                itemCount: shifts.length,
                itemBuilder: (context, i) {
                  final s = shifts[i];
                  final name = workshops.nameOf(s.traineeId);
                  final length = s.length;
                  return GridContainer(
                    child: ListTile(
                      key: ValueKey('shift-${s.id}'),
                      shape: AppTheme.shape(14),
                      leading: Icon(s.open ? Icons.timelapse : Icons.schedule, color: Theme.of(context).colorScheme.tertiary),
                      title: Text(name.isEmpty ? dayText(context, s.checkIn) : name),
                      subtitle: Text(
                        [
                          dayText(context, s.checkIn),
                          if (s.open) 'No check-out'.tr else '${timeText(context, s.checkIn)} – ${timeText(context, s.checkOut!)}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFeatures: figures),
                      ),
                      trailing: Text(
                        length == null ? '?' : hoursText(length),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: figures),
                      ),
                      onTap: () => unawaited(openShiftSheet(context, shift: s, traineeName: name)),
                    ),
                  );
                },
              ),
            ],
            if (waiting.isNotEmpty)
              SliverToBoxAdapter(
                child: GridContainer(child: SectionTitle('Skills to sign off', count: waiting.length)),
              ),
            SliverList.builder(
              itemCount: waiting.length,
              itemBuilder: (context, i) {
                final r = waiting[i];
                final skill = trade.skill(r.skillCode)!;
                final name = workshops.nameOf(r.traineeId);
                final tile = GridContainer(
                  child: ListTile(
                    key: ValueKey('skill-${r.key}'),
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
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      }),
    );
  }
}
