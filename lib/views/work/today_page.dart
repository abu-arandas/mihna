import 'dart:async';

import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/breakpoints.dart';
import '../../config/theme.dart';
import '../../controllers/logbook_controller.dart';
import '../../models/job.dart';
import '../../models/membership.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/motion.dart';
import 'job_sheet.dart';
import 'work_bits.dart';

/// The trainee's day: checking in and out, and the jobs their supervisor gave them.
class TodayPage extends StatelessWidget {
  const TodayPage({required this.me, super.key});

  final Membership me;

  @override
  Widget build(BuildContext context) {
    final logbook = Get.find<LogbookController>();
    return RefreshIndicator(
      onRefresh: logbook.sync,
      child: Obx(() {
        final jobs = logbook.jobsOf(me.userId);
        final todo = jobs.where((j) => j.status == JobStatus.assigned).toList()..sort((a, b) => a.assignedAt.compareTo(b.assignedAt));
        final waiting = jobs.where((j) => j.status == JobStatus.done).toList();
        final checked = jobs.where((j) => j.status == JobStatus.checked).take(5).toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            GridContainer(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: ShiftCard(shift: logbook.openShiftOf(me.userId)),
              ),
            ),
            GridContainer(child: SectionTitle('My jobs', count: todo.length)),
            if (todo.isEmpty)
              const EmptyState(icon: Icons.build_circle_outlined, title: 'No jobs for you yet', message: 'Your supervisor gives you jobs here.')
            else
              for (final (i, j) in todo.indexed)
                Appear(
                  key: ValueKey('todo-${j.id}'),
                  delay: AppTheme.stagger * i.clamp(0, 6),
                  child: JobTile(
                    job: j,
                    onTap: () => unawaited(openJobSheet(context, jobId: j.id, traineeName: me.displayName, supervisor: false)),
                  ),
                ),
            if (waiting.isNotEmpty) ...[
              GridContainer(child: SectionTitle('Waiting for a check', count: waiting.length)),
              for (final j in waiting)
                JobTile(
                  job: j,
                  onTap: () => unawaited(openJobSheet(context, jobId: j.id, traineeName: me.displayName, supervisor: false)),
                ),
            ],
            if (checked.isNotEmpty) ...[
              const GridContainer(child: SectionTitle('Checked lately')),
              for (final j in checked)
                JobTile(
                  job: j,
                  onTap: () => unawaited(openJobSheet(context, jobId: j.id, traineeName: me.displayName, supervisor: false)),
                ),
            ],
          ],
        );
      }),
    );
  }
}

/// Checked in or not, with the one button that changes it. While checked in, the time so far ticks each minute.
class ShiftCard extends StatefulWidget {
  const ShiftCard({required this.shift, super.key});

  final Shift? shift;

  @override
  State<ShiftCard> createState() => _ShiftCardState();
}

class _ShiftCardState extends State<ShiftCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && widget.shift != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final logbook = Get.find<LogbookController>();
    final shift = widget.shift;
    final inside = shift != null;
    return AnimatedContainer(
      duration: reduceMotion(context) ? Duration.zero : AppTheme.slow,
      curve: AppTheme.curve,
      decoration: ShapeDecoration(color: inside ? scheme.primaryContainer : scheme.surfaceContainerHigh, shape: AppTheme.shape(20)),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(inside ? Icons.handyman : Icons.door_front_door_outlined, color: inside ? scheme.onPrimaryContainer : scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (inside ? 'In the workshop' : 'Not checked in').tr,
                  style: theme.textTheme.titleMedium?.copyWith(color: inside ? scheme.onPrimaryContainer : null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            inside
                ? 'Since @time · @length so far'.trParams({
                    'time': timeText(context, shift.checkIn),
                    'length': hoursText(DateTime.now().difference(shift.checkIn)),
                  })
                : 'Check in when you start, and out when you leave. Your supervisor confirms the hours.'.tr,
            style: TextStyle(color: inside ? scheme.onPrimaryContainer : scheme.onSurfaceVariant, fontFeatures: figures),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: PressScale(
              child: inside
                  ? OutlinedButton.icon(
                      key: const Key('check-out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.onPrimaryContainer,
                        side: BorderSide(color: scheme.onPrimaryContainer.withValues(alpha: 0.6)),
                      ),
                      onPressed: () => unawaited(logbook.checkOut()),
                      icon: const Icon(Icons.logout),
                      label: Text('Check out'.tr),
                    )
                  : FilledButton.icon(
                      key: const Key('check-in'),
                      onPressed: () => unawaited(logbook.checkIn()),
                      icon: const Icon(Icons.login),
                      label: Text('Check in'.tr),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One job in a list: what, which car, and where it stands.
class JobTile extends StatelessWidget {
  const JobTile({required this.job, required this.onTap, this.traineeName, super.key});

  final Job job;
  final VoidCallback onTap;

  /// Shown on a supervisor's lists.
  final String? traineeName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final minutes = job.checkedMinutes ?? job.minutes;
    final detail = [
      ?traineeName,
      if (job.vehicle.isNotEmpty) job.vehicle,
      if (job.status == JobStatus.assigned) job.status.label else if (minutes != null) hoursText(Duration(minutes: minutes)),
    ].join(' · ');
    return GridContainer(
      child: ListTile(
        shape: AppTheme.shape(14),
        onTap: onTap,
        leading: Icon(job.status.icon, color: job.status.color(scheme)),
        title: Text(job.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFeatures: figures),
        ),
        trailing: job.skillCodes.isEmpty
            ? const Icon(Icons.chevron_right)
            : Badge(
                label: Text('${job.skillCodes.length}'),
                backgroundColor: scheme.secondary,
                textColor: scheme.onSecondary,
                child: const Icon(Icons.checklist),
              ),
      ),
    );
  }
}
