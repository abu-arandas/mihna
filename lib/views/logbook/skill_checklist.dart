import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/brand.dart';
import '../../config/breakpoints.dart';
import '../../config/theme.dart';
import '../../controllers/logbook_controller.dart';
import '../../models/skill_record.dart';
import '../../models/trade.dart';
import '../../widgets/motion.dart';
import '../../widgets/stitch_line.dart';
import 'skill_sheet.dart';
import 'skill_status.dart';

/// One trainee's checklist for the trade: how far they are, then each area and its skills with where they stand.
/// The trainee opens a skill to log practice; a supervisor opens one to sign it off.
class SkillChecklist extends StatelessWidget {
  const SkillChecklist({required this.traineeId, required this.traineeName, required this.reviewer, super.key});

  final String traineeId;
  final String traineeName;
  final bool reviewer;

  @override
  Widget build(BuildContext context) {
    final logbook = Get.find<LogbookController>();
    final trade = Trade.all[Brand.trade]!;
    final language = Get.locale?.languageCode ?? 'ar';
    return RefreshIndicator(
      onRefresh: logbook.sync,
      child: Obx(() {
        SkillStatus statusOf(Skill s) => logbook.recordOf(traineeId, s.code)?.status ?? SkillStatus.notStarted;
        final total = trade.skills.length;
        final signed = trade.skills.where((s) => statusOf(s) == SkillStatus.signedOff).length;
        final waiting = trade.skills.where((s) => statusOf(s) == SkillStatus.practised).length;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: GridContainer(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
                  child: _Progress(name: traineeName, trade: trade.title(language), signed: signed, waiting: waiting, total: total),
                ),
              ),
            ),
            for (final (i, area) in trade.areas.indexed) ...[
              SliverToBoxAdapter(
                child: GridContainer(
                  child: Appear(
                    delay: AppTheme.stagger * i.clamp(0, 6),
                    child: _AreaHeader(
                      title: area.title(language),
                      signed: area.skills.where((s) => statusOf(s) == SkillStatus.signedOff).length,
                      total: area.skills.length,
                    ),
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: area.skills.length,
                itemBuilder: (context, j) {
                  final skill = area.skills[j];
                  return GridContainer(
                    child: _SkillTile(
                      skill: skill,
                      record: logbook.recordOf(traineeId, skill.code),
                      language: language,
                      onTap: () {
                        openSkillSheet(context, skill: skill, traineeId: traineeId, traineeName: traineeName, reviewer: reviewer);
                      },
                    ),
                  );
                },
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        );
      }),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.name, required this.trade, required this.signed, required this.waiting, required this.total});

  final String name;
  final String trade;
  final int signed;
  final int waiting;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const figures = [FontFeature.tabularFigures()];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(trade.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Semantics(header: true, child: Text(name, style: theme.textTheme.headlineSmall)),
        const SizedBox(height: 6),
        const SewIn(child: StitchLine()),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            PopOnChange(
              value: signed,
              child: Text(
                '$signed',
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600, color: scheme.primary, fontFeatures: figures),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 6, bottom: 6),
              child: Text('of @total signed off'.trParams({'total': '$total'}), style: theme.textTheme.titleMedium?.copyWith(fontFeatures: figures)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRSuperellipse(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: total == 0 ? 0 : signed / total),
            duration: reduceMotion(context) ? Duration.zero : AppTheme.slow,
            curve: AppTheme.curve,
            builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 10, backgroundColor: scheme.surfaceContainerHighest),
          ),
        ),
        if (waiting > 0) ...[
          const SizedBox(height: 8),
          Text(
            '@count waiting for sign-off'.trParams({'count': '$waiting'}),
            style: TextStyle(color: scheme.tertiary, fontWeight: FontWeight.w500, fontFeatures: figures),
          ),
        ],
      ],
    );
  }
}

class _AreaHeader extends StatelessWidget {
  const _AreaHeader({required this.title, required this.signed, required this.total});

  final String title;
  final int signed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final complete = signed == total;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 24, 16, 4),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
          // The one celebration: a whole area signed off.
          if (complete)
            PopIn(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium, size: 18, color: scheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Area done'.tr,
                    style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          else
            Text(
              '$signed/$total',
              style: TextStyle(color: scheme.onSurfaceVariant, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
        ],
      ),
    );
  }
}

class _SkillTile extends StatelessWidget {
  const _SkillTile({required this.skill, required this.record, required this.language, required this.onTap});

  final Skill skill;
  final SkillRecord? record;
  final String language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = record?.status ?? SkillStatus.notStarted;
    final detail = switch (status) {
      SkillStatus.returned when record!.reviewNote.isNotEmpty => record!.reviewNote,
      SkillStatus.notStarted || SkillStatus.signedOff => null,
      _ => status.label,
    };
    return ListTile(
      onTap: onTap,
      shape: AppTheme.shape(14),
      leading: AnimatedSwitcher(
        duration: reduceMotion(context) ? Duration.zero : AppTheme.slow,
        switchInCurve: AppTheme.pop,
        transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
        child: Icon(status.icon, key: ValueKey(status), color: status.color(scheme)),
      ),
      title: Text(skill.title(language)),
      subtitle: detail == null
          ? null
          : Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: status.color(scheme)),
            ),
      trailing: skill.safety ? SafetyTag(compact: context.isMobile) : null,
    );
  }
}
