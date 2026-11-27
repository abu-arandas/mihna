import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/skill_record.dart';

/// How each status looks: its icon, its word and its colour, the same on every page.
extension SkillStatusLook on SkillStatus {
  IconData get icon => switch (this) {
    SkillStatus.notStarted => Icons.radio_button_unchecked,
    SkillStatus.practised => Icons.schedule,
    SkillStatus.signedOff => Icons.verified,
    SkillStatus.returned => Icons.replay,
  };

  String get label => switch (this) {
    SkillStatus.notStarted => 'Not started'.tr,
    SkillStatus.practised => 'Waiting for sign-off'.tr,
    SkillStatus.signedOff => 'Signed off'.tr,
    SkillStatus.returned => 'Sent back'.tr,
  };

  Color color(ColorScheme scheme) => switch (this) {
    SkillStatus.notStarted => scheme.outline,
    SkillStatus.practised => scheme.tertiary,
    SkillStatus.signedOff => scheme.primary,
    SkillStatus.returned => scheme.error,
  };
}

/// A date and time in the app's language, with figures that line up.
String whenText(BuildContext context, DateTime at) {
  final l = MaterialLocalizations.of(context);
  final local = at.toLocal();
  return '${l.formatShortMonthDay(local)} ${l.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}
