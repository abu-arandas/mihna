import 'dart:async';

import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/brand.dart';
import '../../config/theme.dart';
import '../../controllers/logbook_controller.dart';
import '../../models/job.dart';
import '../../models/skill_record.dart';
import '../../models/trade.dart';
import '../../widgets/motion.dart';
import '../logbook/skill_status.dart';
import 'work_bits.dart';

/// One job, opened from a list. The trainee marks it done with the time it took; a supervisor checks a finished job
/// and confirms the time that counts, or calls off one not started.
Future<void> openJobSheet(BuildContext context, {required String jobId, required String traineeName, required bool supervisor}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _JobSheet(jobId: jobId, traineeName: traineeName, supervisor: supervisor),
);

class _JobSheet extends StatefulWidget {
  const _JobSheet({required this.jobId, required this.traineeName, required this.supervisor});

  final String jobId;
  final String traineeName;
  final bool supervisor;

  @override
  State<_JobSheet> createState() => _JobSheetState();
}

class _JobSheetState extends State<_JobSheet> {
  final _note = TextEditingController();
  int? _minutes;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _done(Future<void> Function() action) {
    unawaited(action());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final logbook = Get.find<LogbookController>();
    final trade = Trade.all[Brand.trade]!;
    final language = Get.locale?.languageCode ?? 'ar';
    final job = logbook.jobs[widget.jobId];
    if (job == null) return const SizedBox(height: 120);
    final minutes = _minutes ?? job.minutes ?? 60;
    final skills = [for (final c in job.skillCodes) ?trade.skill(c)];
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.supervisor) Text(widget.traineeName, style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
          Text(job.title, style: theme.textTheme.titleLarge),
          if (job.vehicle.isNotEmpty) Text(job.vehicle, style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(job.status.icon, size: 18, color: job.status.color(scheme)),
              const SizedBox(width: 6),
              Text(
                job.status.label,
                style: TextStyle(color: job.status.color(scheme), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          if (skills.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Skills on this job'.tr, style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in skills)
                  Chip(
                    avatar: Icon(
                      (logbook.recordOf(job.traineeId, s.code)?.status ?? SkillStatus.notStarted).icon,
                      size: 16,
                      color: (logbook.recordOf(job.traineeId, s.code)?.status ?? SkillStatus.notStarted).color(scheme),
                    ),
                    label: Text(s.title(language)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          if (job.note.isNotEmpty) ...[const SizedBox(height: 16), Text('Trainee note'.tr, style: theme.textTheme.labelMedium), Text(job.note)],
          if (job.minutes != null && job.status != JobStatus.assigned) ...[
            const SizedBox(height: 4),
            Text(
              'The trainee says @time'.trParams({'time': hoursText(Duration(minutes: job.minutes!))}),
              style: TextStyle(color: scheme.onSurfaceVariant, fontFeatures: figures),
            ),
          ],
          if (job.checkNote.isNotEmpty) ...[const SizedBox(height: 16), Text('Supervisor note'.tr, style: theme.textTheme.labelMedium), Text(job.checkNote)],
          const SizedBox(height: 20),
          ...switch ((job.status, widget.supervisor)) {
            (JobStatus.checked, _) => [
              Row(
                children: [
                  PopIn(child: Icon(Icons.verified, color: scheme.primary)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Checked. @time count as hands-on hours.'.trParams({'time': hoursText(Duration(minutes: job.checkedMinutes ?? job.minutes ?? 0))}),
                      style: const TextStyle(fontFeatures: figures),
                    ),
                  ),
                ],
              ),
            ],
            (JobStatus.cancelled, _) => [Text('This job was called off.'.tr, style: TextStyle(color: scheme.onSurfaceVariant))],
            (JobStatus.assigned, false) || (JobStatus.done, false) => [
              Text('How long did it take?'.tr, style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              MinutesStepper(minutes: minutes, onChanged: (m) => setState(() => _minutes = m)),
              const SizedBox(height: 12),
              TextField(
                key: const Key('job-note'),
                controller: _note,
                maxLines: 3,
                minLines: 1,
                maxLength: 1000,
                decoration: InputDecoration(labelText: 'What did you do? (car, job, what you learned)'.tr),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: PressScale(
                  child: FilledButton.icon(
                    key: const Key('finish-job'),
                    icon: const Icon(Icons.check),
                    onPressed: () => _done(() => logbook.finishJob(job, minutes: minutes, note: _note.text.isEmpty ? job.note : _note.text)),
                    label: Text((job.status == JobStatus.done ? 'Update' : 'Mark done').tr),
                  ),
                ),
              ),
            ],
            (JobStatus.done, true) => [
              Text('Time that counts'.tr, style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              MinutesStepper(minutes: minutes, onChanged: (m) => setState(() => _minutes = m)),
              const SizedBox(height: 12),
              TextField(
                key: const Key('check-note'),
                controller: _note,
                maxLines: 3,
                minLines: 1,
                maxLength: 1000,
                decoration: InputDecoration(labelText: 'Note for the trainee'.tr),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: PressScale(
                  child: FilledButton.icon(
                    key: const Key('check-job'),
                    icon: const Icon(Icons.verified),
                    onPressed: () => _done(() => logbook.checkJob(job, minutes: minutes, note: _note.text)),
                    label: Text('Check and confirm the time'.tr),
                  ),
                ),
              ),
            ],
            (JobStatus.assigned, true) => [
              Text('Waiting for the trainee to finish it.'.tr, style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('cancel-job'),
                icon: const Icon(Icons.block),
                onPressed: () => _done(() => logbook.cancelJob(job)),
                label: Text('Call off this job'.tr),
              ),
            ],
          },
          const SizedBox(height: AppTheme.rise),
        ],
      ),
    );
  }
}
