import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/theme.dart';
import '../../models/job.dart';
import '../../widgets/motion.dart';

const figures = [FontFeature.tabularFigures()];

/// A length of time the way a workshop says it: "8h 25m", "45m", "0h".
String hoursText(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0 && m > 0) return '@mm'.trParams({'m': '$m'});
  if (m == 0) return '@hh'.trParams({'h': '$h'});
  return '@hh @mm'.trParams({'h': '$h', 'm': '$m'});
}

/// A clock time in the app's language.
String timeText(BuildContext context, DateTime at) => MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(at.toLocal()));

/// A day in the app's language, with its weekday: "Thu, Nov 26".
String dayText(BuildContext context, DateTime at) => MaterialLocalizations.of(context).formatMediumDate(at.toLocal());

/// How each job status looks, the same on every page.
extension JobStatusLook on JobStatus {
  IconData get icon => switch (this) {
    JobStatus.assigned => Icons.build_circle_outlined,
    JobStatus.done => Icons.schedule,
    JobStatus.checked => Icons.verified,
    JobStatus.cancelled => Icons.block,
  };

  String get label => switch (this) {
    JobStatus.assigned => 'To do'.tr,
    JobStatus.done => 'Waiting for a check'.tr,
    JobStatus.checked => 'Checked'.tr,
    JobStatus.cancelled => 'Called off'.tr,
  };

  Color color(ColorScheme scheme) => switch (this) {
    JobStatus.assigned => scheme.secondary,
    JobStatus.done => scheme.tertiary,
    JobStatus.checked => scheme.primary,
    JobStatus.cancelled => scheme.outline,
  };
}

/// A list's section title, with a count.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.count, super.key});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Semantics(header: true, child: Text(title.tr, style: theme.textTheme.titleMedium)),
          ),
          if (count != null)
            Text(
              '$count',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontFeatures: figures),
            ),
        ],
      ),
    );
  }
}

/// Picks a time in quarter hours, from 15 minutes to 12 hours: a big number between a minus and a plus, since a
/// mechanic's hands are not always clean enough to type.
class MinutesStepper extends StatelessWidget {
  const MinutesStepper({required this.minutes, required this.onChanged, super.key});

  final int minutes;
  final ValueChanged<int> onChanged;

  static const step = 15;
  static const max = 720;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton.filledTonal(
          key: const Key('minutes-less'),
          tooltip: 'Less time'.tr,
          onPressed: minutes > step ? () => onChanged(minutes - step) : null,
          icon: const Icon(Icons.remove),
        ),
        Expanded(
          child: PopOnChange(
            value: minutes,
            child: Text(
              hoursText(Duration(minutes: minutes)),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, fontFeatures: figures),
            ),
          ),
        ),
        IconButton.filledTonal(
          key: const Key('minutes-more'),
          tooltip: 'More time'.tr,
          onPressed: minutes < max ? () => onChanged(minutes + step) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

/// A small tile with a big number: confirmed hours, and what still waits.
class HoursTile extends StatelessWidget {
  const HoursTile({required this.label, required this.confirmed, required this.waiting, required this.icon, super.key});

  final String label;
  final Duration confirmed;
  final Duration waiting;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(color: scheme.surfaceContainerHigh, shape: AppTheme.shape(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label.tr, style: theme.textTheme.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 8),
            PopOnChange(
              value: confirmed,
              child: Text(
                hoursText(confirmed),
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, color: scheme.primary, fontFeatures: figures),
              ),
            ),
            Text(
              waiting > Duration.zero ? '+@time waiting'.trParams({'time': hoursText(waiting)}) : 'Confirmed'.tr,
              style: TextStyle(color: waiting > Duration.zero ? scheme.tertiary : scheme.onSurfaceVariant, fontFeatures: figures),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
