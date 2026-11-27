import 'dart:async';

import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/theme.dart';
import '../../controllers/logbook_controller.dart';
import '../../models/skill_record.dart';
import '../../models/trade.dart';
import '../../widgets/motion.dart';
import 'skill_status.dart';

/// One skill, opened from a checklist or the sign-off list. A trainee logs that they practised it, with a note; a
/// supervisor reads the note and signs it off or sends it back with one.
Future<void> openSkillSheet(BuildContext context, {required Skill skill, required String traineeId, required String traineeName, required bool reviewer}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SkillSheet(skill: skill, traineeId: traineeId, traineeName: traineeName, reviewer: reviewer),
    );

class _SkillSheet extends StatefulWidget {
  const _SkillSheet({required this.skill, required this.traineeId, required this.traineeName, required this.reviewer});

  final Skill skill;
  final String traineeId;
  final String traineeName;
  final bool reviewer;

  @override
  State<_SkillSheet> createState() => _SkillSheetState();
}

class _SkillSheetState extends State<_SkillSheet> {
  final _note = TextEditingController();

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
    final language = Get.locale?.languageCode ?? 'ar';
    final record = logbook.recordOf(widget.traineeId, widget.skill.code);
    final status = record?.status ?? SkillStatus.notStarted;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.reviewer) Text(widget.traineeName, style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
          Text(widget.skill.title(language), style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(status.icon, size: 18, color: status.color(scheme)),
              const SizedBox(width: 6),
              Text(
                status.label,
                style: TextStyle(color: status.color(scheme), fontWeight: FontWeight.w500),
              ),
              if (widget.skill.safety) ...[const SizedBox(width: 12), const SafetyTag()],
            ],
          ),
          if (record != null && record.note.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Trainee note'.tr, style: theme.textTheme.labelMedium),
            Text(record.note),
          ],
          if (record != null && status != SkillStatus.notStarted) ...[
            const SizedBox(height: 4),
            Text(
              'Practised @when'.trParams({'when': whenText(context, record.practisedAt)}),
              style: TextStyle(color: scheme.onSurfaceVariant, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
          if (record != null && record.reviewNote.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Supervisor note'.tr, style: theme.textTheme.labelMedium),
            Text(record.reviewNote),
          ],
          const SizedBox(height: 20),
          if (status == SkillStatus.signedOff)
            Row(
              children: [
                PopIn(child: Icon(Icons.verified, color: scheme.primary)),
                const SizedBox(width: 8),
                Expanded(child: Text('Signed off. This one is on the record for good.'.tr)),
              ],
            )
          else if (!widget.reviewer) ...[
            TextField(
              key: const Key('practice-note'),
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
                  key: const Key('log-practice'),
                  icon: const Icon(Icons.check),
                  onPressed: () => _done(() => logbook.practise(widget.skill.code, _note.text)),
                  label: Text((status == SkillStatus.notStarted ? 'Log practice' : 'Log it again').tr),
                ),
              ),
            ),
          ] else if (status == SkillStatus.practised) ...[
            TextField(
              key: const Key('review-note'),
              controller: _note,
              maxLines: 3,
              minLines: 1,
              maxLength: 1000,
              decoration: InputDecoration(labelText: 'Note for the trainee'.tr),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('send-back'),
                    icon: const Icon(Icons.replay),
                    onPressed: () {
                      if (_note.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Write what to practise again.'.tr)));
                        return;
                      }
                      _done(() => logbook.review(widget.traineeId, widget.skill.code, signedOff: false, note: _note.text));
                    },
                    label: Text('Send back'.tr),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PressScale(
                    child: FilledButton.icon(
                      key: const Key('sign-off'),
                      icon: const Icon(Icons.verified),
                      onPressed: () => _done(() => logbook.review(widget.traineeId, widget.skill.code, signedOff: true, note: _note.text)),
                      label: Text('Sign off'.tr),
                    ),
                  ),
                ),
              ],
            ),
          ] else
            Text(
              (status == SkillStatus.notStarted
                      ? 'The trainee has not logged this skill yet.'
                      : 'Sent back. It comes back here when the trainee logs it again.')
                  .tr,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          const SizedBox(height: AppTheme.rise),
        ],
      ),
    );
  }
}

/// The safety mark on a skill about keeping people safe: amber, like the vest.
class SafetyTag extends StatelessWidget {
  const SafetyTag({this.compact = false, super.key});

  /// Only the mark, for a list row on a phone; the word goes to screen readers.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(color: scheme.secondary, shape: AppTheme.shape(6)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.health_and_safety_outlined, size: 14, color: scheme.onSecondary),
            const SizedBox(width: 3),
            Text(
              'Safety'.tr,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
