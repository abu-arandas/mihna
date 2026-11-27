import 'dart:async';

import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/breakpoints.dart';
import '../../controllers/logbook_controller.dart';
import '../../controllers/workshop_controller.dart';
import '../../models/job.dart';
import '../../widgets/empty_state.dart';
import 'assign_job_page.dart';
import 'job_sheet.dart';
import 'today_page.dart';
import 'work_bits.dart';

/// The supervisor's jobs: giving one out, what waits for a check, and what the trainees are on.
class JobsBoard extends StatelessWidget {
  const JobsBoard({this.traineeId, super.key});

  /// Only this trainee's jobs, when shown on their page.
  final String? traineeId;

  static Future<void> give(BuildContext context, {String? traineeId}) =>
      Navigator.of(context).push<void>(MaterialPageRoute(builder: (context) => AssignJobPage(traineeId: traineeId)));

  @override
  Widget build(BuildContext context) {
    final logbook = Get.find<LogbookController>();
    final workshops = Get.find<WorkshopController>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('give-job'),
        heroTag: 'give-job-$traineeId',
        onPressed: () => unawaited(give(context, traineeId: traineeId)),
        icon: const Icon(Icons.add_task),
        label: Text('Give a job'.tr),
      ),
      body: RefreshIndicator(
        onRefresh: () async => Future.wait([logbook.sync(), workshops.loadMembers()]),
        child: Obx(() {
          final all = logbook.jobs.values.where((j) => traineeId == null || j.traineeId == traineeId).toList()
            ..sort((a, b) => a.assignedAt.compareTo(b.assignedAt));
          final done = all.where((j) => j.status == JobStatus.done).toList();
          final todo = all.where((j) => j.status == JobStatus.assigned).toList();
          final checked = all.where((j) => j.status == JobStatus.checked).toList().reversed.take(10).toList();
          Widget tile(Job j) => JobTile(
            job: j,
            traineeName: traineeId == null ? workshops.nameOf(j.traineeId) : null,
            onTap: () => unawaited(openJobSheet(context, jobId: j.id, traineeName: workshops.nameOf(j.traineeId), supervisor: true)),
          );
          if (done.isEmpty && todo.isEmpty && checked.isEmpty) {
            return ListView(
              children: const [
                EmptyState(
                  icon: Icons.add_task,
                  title: 'No jobs yet',
                  message: 'Give a trainee a job on a real car. Its skills are logged when they finish it.',
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              if (done.isNotEmpty) ...[GridContainer(child: SectionTitle('Waiting for a check', count: done.length)), for (final j in done) tile(j)],
              if (todo.isNotEmpty) ...[GridContainer(child: SectionTitle('Being worked on', count: todo.length)), for (final j in todo) tile(j)],
              if (checked.isNotEmpty) ...[const GridContainer(child: SectionTitle('Checked lately')), for (final j in checked) tile(j)],
            ],
          );
        }),
      ),
    );
  }
}
