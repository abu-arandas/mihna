import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/brand.dart';
import '../../config/breakpoints.dart';
import '../../controllers/logbook_controller.dart';
import '../../controllers/workshop_controller.dart';
import '../../models/trade.dart';

/// A supervisor gives a trainee a job: who, what, which car, and the checklist skills it practises. Saved on the
/// phone at once, like every change.
class AssignJobPage extends StatefulWidget {
  const AssignJobPage({this.traineeId, super.key});

  /// The trainee to start with, when opened from one trainee's page.
  final String? traineeId;

  @override
  State<AssignJobPage> createState() => _AssignJobPageState();
}

class _AssignJobPageState extends State<AssignJobPage> {
  final _title = TextEditingController();
  final _vehicle = TextEditingController();
  final _skills = <String>{};
  String? _trainee;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _trainee = widget.traineeId;
  }

  @override
  void dispose() {
    _title.dispose();
    _vehicle.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final trainee = _trainee;
    if (trainee == null || _title.text.trim().isEmpty) {
      setState(() => _problem = 'Choose a trainee and write what the job is.');
      return;
    }
    final logbook = Get.find<LogbookController>();
    final trade = Trade.all[Brand.trade]!;
    await logbook.assignJob(
      traineeId: trainee,
      title: _title.text,
      vehicle: _vehicle.text,
      // In the checklist's order, not the order they were tapped.
      skillCodes: [
        for (final s in trade.skills)
          if (_skills.contains(s.code)) s.code,
      ],
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trade = Trade.all[Brand.trade]!;
    final language = Get.locale?.languageCode ?? 'ar';
    final trainees = Get.find<WorkshopController>().trainees;
    return Scaffold(
      appBar: AppBar(title: Text('Give a job'.tr)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          GridContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    key: const Key('job-trainee'),
                    initialValue: _trainee,
                    decoration: InputDecoration(labelText: 'Trainee'.tr),
                    items: [for (final t in trainees) DropdownMenuItem(value: t.userId, child: Text(t.displayName))],
                    onChanged: (v) => setState(() => _trainee = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('job-title'),
                    controller: _title,
                    maxLength: 120,
                    decoration: InputDecoration(labelText: 'The job'.tr, hintText: 'Front brake pads'.tr),
                  ),
                  TextField(
                    key: const Key('job-vehicle'),
                    controller: _vehicle,
                    maxLength: 80,
                    decoration: InputDecoration(labelText: 'Car (optional)'.tr, hintText: '2014 Corolla'.tr),
                  ),
                  const SizedBox(height: 8),
                  Text('Skills it practises'.tr, style: theme.textTheme.titleMedium),
                  Text(
                    'When the trainee marks the job done, these are logged for you to sign off.'.tr,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          for (final area in trade.areas)
            GridContainer(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(area.title(language), style: theme.textTheme.labelLarge),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final s in area.skills)
                          FilterChip(
                            key: Key('job-skill-${s.code}'),
                            label: Text(s.title(language)),
                            avatar: s.safety ? const Icon(Icons.health_and_safety_outlined, size: 16) : null,
                            selected: _skills.contains(s.code),
                            onSelected: _skills.length >= 12 && !_skills.contains(s.code)
                                ? null
                                : (on) => setState(() => on ? _skills.add(s.code) : _skills.remove(s.code)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 96),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_problem != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_problem!.tr, style: TextStyle(color: theme.colorScheme.error)),
                ),
              FilledButton.icon(key: const Key('save-job'), onPressed: _save, icon: const Icon(Icons.send), label: Text('Give the job'.tr)),
            ],
          ),
        ),
      ),
    );
  }
}
