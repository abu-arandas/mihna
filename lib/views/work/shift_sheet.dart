import 'dart:async';

import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/theme.dart';
import '../../controllers/logbook_controller.dart';
import '../../models/job.dart';
import 'work_bits.dart';

/// A supervisor confirms a trainee's shift: the times as the phone saw them, or fixed (a check-out forgotten, a
/// check-in made late). Once confirmed, the shift counts as workshop hours and stays as it is.
Future<void> openShiftSheet(BuildContext context, {required Shift shift, required String traineeName}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _ShiftSheet(shift: shift, traineeName: traineeName),
);

class _ShiftSheet extends StatefulWidget {
  const _ShiftSheet({required this.shift, required this.traineeName});

  final Shift shift;
  final String traineeName;

  @override
  State<_ShiftSheet> createState() => _ShiftSheetState();
}

class _ShiftSheetState extends State<_ShiftSheet> {
  late DateTime _in = widget.shift.checkIn.toLocal();
  // A forgotten check-out: start from eight hours later, or now if that is sooner.
  late DateTime _out = (widget.shift.checkOut ?? _soonest(widget.shift.checkIn.add(const Duration(hours: 8)), DateTime.now())).toLocal();

  static DateTime _soonest(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  Future<void> _pick({required bool checkIn}) async {
    final current = checkIn ? _in : _out;
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current));
    if (picked == null || !mounted) return;
    setState(() {
      final at = DateTime(current.year, current.month, current.day, picked.hour, picked.minute);
      if (checkIn) {
        _in = at;
      } else {
        // A check-out earlier than the check-in is the next morning (a night shift).
        _out = at.isAfter(_in) ? at : at.add(const Duration(days: 1));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final length = _out.difference(_in);
    final problem = switch (length) {
      final d when d <= Duration.zero => 'Check-out comes after check-in',
      final d when d > const Duration(hours: 16) => 'A shift is at most 16 hours',
      _ => null,
    };
    final confirmed = widget.shift.confirmed;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.traineeName, style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
          Text(dayText(context, widget.shift.checkIn), style: theme.textTheme.titleLarge),
          if (widget.shift.open && !confirmed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('No check-out. Set the time they left.'.tr, style: TextStyle(color: scheme.tertiary)),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TimeBox(label: 'Checked in', at: _in, onTap: confirmed ? null : () => unawaited(_pick(checkIn: true)), key: const Key('shift-in')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeBox(label: 'Checked out', at: _out, onTap: confirmed ? null : () => unawaited(_pick(checkIn: false)), key: const Key('shift-out')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            problem?.tr ?? hoursText(length),
            style: theme.textTheme.titleMedium?.copyWith(color: problem == null ? scheme.primary : scheme.error, fontFeatures: figures),
          ),
          const SizedBox(height: 20),
          if (confirmed)
            Row(
              children: [
                Icon(Icons.verified, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('Confirmed. These hours are on the record.'.tr)),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('confirm-shift'),
                icon: const Icon(Icons.verified),
                onPressed: problem != null
                    ? null
                    : () {
                        unawaited(Get.find<LogbookController>().confirmShift(widget.shift, checkIn: _in, checkOut: _out));
                        Navigator.of(context).pop();
                      },
                label: Text('Confirm the shift'.tr),
              ),
            ),
          const SizedBox(height: AppTheme.rise),
        ],
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.label, required this.at, required this.onTap, super.key});

  final String label;
  final DateTime at;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      customBorder: AppTheme.shape(14),
      child: Ink(
        decoration: ShapeDecoration(color: theme.colorScheme.surfaceContainerHigh, shape: AppTheme.shape(14)),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.tr, style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(timeText(context, at), style: theme.textTheme.titleLarge?.copyWith(fontFeatures: figures)),
                ),
                if (onTap != null) Icon(Icons.edit_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
