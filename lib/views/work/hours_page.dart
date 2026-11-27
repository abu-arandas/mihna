import 'dart:async';

import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/breakpoints.dart';
import '../../config/theme.dart';
import '../../controllers/logbook_controller.dart';
import '../../models/job.dart';
import '../../widgets/empty_state.dart';
import 'shift_sheet.dart';
import 'work_bits.dart';

/// One trainee's hours: in the workshop (their shifts) and hands-on (their checked jobs), confirmed and waiting, then
/// each shift. A supervisor opens a shift to confirm it.
class HoursPage extends StatelessWidget {
  const HoursPage({required this.traineeId, required this.traineeName, required this.supervisor, super.key});

  final String traineeId;
  final String traineeName;
  final bool supervisor;

  @override
  Widget build(BuildContext context) {
    final logbook = Get.find<LogbookController>();
    return RefreshIndicator(
      onRefresh: logbook.sync,
      child: Obx(() {
        final hours = logbook.hoursOf(traineeId);
        final shifts = logbook.shiftsOf(traineeId);
        return ListView(
          padding: const EdgeInsets.only(top: 20, bottom: 32),
          children: [
            GridContainer(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: HoursTile(
                        label: 'Workshop',
                        icon: Icons.schedule,
                        confirmed: hours.workshop,
                        waiting: hours.workshopWaiting,
                        key: const Key('hours-workshop'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: HoursTile(
                        label: 'Hands-on',
                        icon: Icons.handyman_outlined,
                        confirmed: hours.handsOn,
                        waiting: hours.handsOnWaiting,
                        key: const Key('hours-hands-on'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            GridContainer(child: SectionTitle('Shifts', count: shifts.length)),
            if (shifts.isEmpty)
              const EmptyState(icon: Icons.event_available_outlined, title: 'No shifts yet', message: 'A shift starts when the trainee checks in.')
            else
              for (final s in shifts)
                GridContainer(
                  child: _ShiftTile(
                    shift: s,
                    onTap: supervisor && !s.confirmed ? () => unawaited(openShiftSheet(context, shift: s, traineeName: traineeName)) : null,
                  ),
                ),
          ],
        );
      }),
    );
  }
}

class _ShiftTile extends StatelessWidget {
  const _ShiftTile({required this.shift, this.onTap});

  final Shift shift;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final length = shift.length;
    final times = [timeText(context, shift.checkIn), if (shift.checkOut != null) timeText(context, shift.checkOut!) else 'now'.tr].join(' – ');
    return ListTile(
      shape: AppTheme.shape(14),
      onTap: onTap,
      leading: Icon(
        shift.confirmed ? Icons.verified : (shift.open ? Icons.timelapse : Icons.schedule),
        color: shift.confirmed ? scheme.primary : scheme.tertiary,
      ),
      title: Text(dayText(context, shift.checkIn)),
      subtitle: Text(
        [times, (shift.confirmed ? 'Confirmed' : (shift.open ? 'Checked in' : 'Waiting for a supervisor')).tr].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFeatures: figures),
      ),
      trailing: Text(
        length == null ? '' : hoursText(length),
        style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: figures),
      ),
    );
  }
}
