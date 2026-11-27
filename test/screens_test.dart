// Builds Mihna's main screens at a phone's width, in Arabic and English, light and dark, and fails on any layout
// error (a row that overflows, a text that does not fit). The services are stand-ins that live only in this test:
// the app itself always runs on Supabase (ARCHITECTURE.md, rule 3).
//
// With SHOTS=1 it also saves each screen as a picture in .shots/, to look at:
//
//   SHOTS=1 flutter test test/screens_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mihna/config/theme.dart';
import 'package:mihna/controllers/logbook_controller.dart';
import 'package:mihna/controllers/session_controller.dart';
import 'package:mihna/controllers/workshop_controller.dart';
import 'package:mihna/l10n/translations.dart';
import 'package:mihna/models/change.dart';
import 'package:mihna/models/job.dart';
import 'package:mihna/models/membership.dart';
import 'package:mihna/models/role.dart';
import 'package:mihna/models/skill_record.dart';
import 'package:mihna/services/auth_service.dart';
import 'package:mihna/services/logbook_service.dart';
import 'package:mihna/services/workshop_service.dart';
import 'package:mihna/views/logbook/workspace_page.dart';
import 'package:mihna/views/workshop/start_workshop_page.dart';

import 'change_queue_test.dart' show MapStore;

const trainee = 'aaaaaaaa-0000-4000-8000-000000000001';
const usta = 'aaaaaaaa-0000-4000-8000-000000000002';
const workshop = 'bbbbbbbb-0000-4000-8000-000000000001';

class StandInAuth implements AuthService {
  StandInAuth(this.userId);

  @override
  final String? userId;

  @override
  String? get email => 'omar@example.com';

  @override
  Stream<String?> get userChanges => const Stream.empty();

  @override
  Stream<void> get passwordRecoveries => const Stream.empty();

  @override
  Future<void> signIn({required String email, required String password}) async {}

  @override
  Future<bool> signUp({required String email, required String password, String? redirectTo}) async => true;

  @override
  Future<void> sendPasswordReset({required String email, String? redirectTo}) async {}

  @override
  Future<void> updatePassword(String password) async {}

  @override
  Future<void> signOut() async {}
}

final people = [
  const Membership(workshopId: workshop, workshopName: 'Abu Ali Auto', userId: usta, role: Role.supervisor, displayName: 'Usta Khaled'),
  const Membership(workshopId: workshop, workshopName: 'Abu Ali Auto', userId: trainee, role: Role.trainee, displayName: 'Omar'),
];

class StandInWorkshops implements WorkshopService {
  StandInWorkshops(this.mine);

  final List<Membership> mine;

  @override
  Future<List<Membership>> myMemberships(String userId) async => mine;

  @override
  Future<List<Membership>> members(String workshopId) async => people;

  @override
  Future<String> startWorkshop({required String name, required String displayName}) async => workshop;

  @override
  Future<void> addMember({required String workshopId, required String email, required Role role, required String displayName}) async {}

  @override
  Future<void> removeMember({required String workshopId, required String userId}) async {}
}

class StandInLogbook implements LogbookService {
  final at = DateTime.utc(2026, 11, 26, 9, 30);

  SkillRecord r(String code, SkillStatus status, {String note = '', String review = ''}) =>
      SkillRecord(workshopId: workshop, traineeId: trainee, skillCode: code, status: status, practisedAt: at, note: note, reviewNote: review);

  @override
  Future<List<SkillRecord>> records(String workshopId) async => [
    for (final c in ['safety.ppe', 'safety.lift', 'safety.fluids', 'safety.fire', 'service.oil', 'service.filters']) r(c, SkillStatus.signedOff),
    r('brakes.pads', SkillStatus.practised, note: 'Front pads on a 2014 Corolla, with Usta Khaled'),
    r('brakes.inspect', SkillStatus.practised),
    r('tools.torque', SkillStatus.returned, review: 'Use the torque wrench, not the impact gun, for the final pass'),
  ];

  @override
  Future<List<Job>> jobs(String workshopId) async => [
    Job(
      id: 'job-1',
      workshopId: workshop,
      traineeId: trainee,
      assignedBy: usta,
      title: 'Front brake pads',
      vehicle: '2014 Corolla',
      skillCodes: const ['brakes.pads', 'brakes.inspect'],
      assignedAt: at,
    ),
    Job(
      id: 'job-2',
      workshopId: workshop,
      traineeId: trainee,
      title: 'Oil and filter change',
      vehicle: 'Hyundai Elantra',
      skillCodes: const ['service.oil'],
      status: JobStatus.done,
      assignedAt: at.subtract(const Duration(days: 1)),
      minutes: 45,
      note: 'Drain plug torqued to spec',
    ),
    Job(
      id: 'job-3',
      workshopId: workshop,
      traineeId: trainee,
      title: 'Battery test and replacement',
      status: JobStatus.checked,
      assignedAt: at.subtract(const Duration(days: 2)),
      minutes: 90,
      checkedMinutes: 75,
    ),
  ];

  @override
  Future<List<Shift>> shifts(String workshopId) async => [
    Shift(
      id: 'shift-1',
      workshopId: workshop,
      traineeId: trainee,
      checkIn: DateTime.utc(2026, 11, 24, 5),
      checkOut: DateTime.utc(2026, 11, 24, 13),
      confirmedAt: DateTime.utc(2026, 11, 24, 14),
    ),
    Shift(id: 'shift-2', workshopId: workshop, traineeId: trainee, checkIn: DateTime.utc(2026, 11, 25, 5), checkOut: DateTime.utc(2026, 11, 25, 12, 30)),
  ];

  @override
  Future<void> send(Change change) async => throw const SocketException('no signal in the pit');
}

Future<void> loadFonts() async {
  final rubik = FontLoader('Rubik')..addFont(File('assets/fonts/Rubik.ttf').readAsBytes().then(ByteData.sublistView));
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      File('${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter-sdk/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
          .readAsBytes()
          .then(ByteData.sublistView),
    );
  await Future.wait([rubik.load(), icons.load()]);
}

void main() {
  setUpAll(loadFonts);
  final shots = Platform.environment['SHOTS'] == '1';

  for (final language in ['ar', 'en']) {
    for (final dark in [false, true]) {
      for (final who in ['trainee', 'supervisor', 'new']) {
        testWidgets('$who, $language, ${dark ? 'dark' : 'light'}', (tester) async {
          tester.view
            ..physicalSize = const Size(390 * 2, 844 * 2)
            ..devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          Get
            ..reset()
            ..addTranslations(AppTranslations().keys)
            ..locale = Locale(language);
          final me = who == 'supervisor' ? usta : trainee;
          final auth = StandInAuth(me);
          final store = MapStore();
          final session = Get.put(SessionController(auth));
          final mine = who == 'new' ? <Membership>[] : people.where((m) => m.userId == me).toList();
          final workshops = Get.put(WorkshopController(StandInWorkshops(mine), store, session));
          Get
            ..put<AuthService>(auth)
            ..put(LogbookController(StandInLogbook(), store));
          await tester.runAsync(workshops.load);
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dark ? AppTheme.dark() : AppTheme.light(),
                locale: Locale(language),
                supportedLocales: const [Locale('ar'), Locale('en')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                home: who == 'new' ? const StartWorkshopPage() : WorkspacePage(membership: workshops.current.value!),
              ),
            ),
          );
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
          await tester.pumpAndSettle();
          final logbook = Get.find<LogbookController>();
          final tag = '$language-${dark ? 'dark' : 'light'}';
          Future<void> tab(int i) async {
            await tester.tap(find.byType(NavigationDestination).at(i));
            await tester.pumpAndSettle();
          }

          Future<void> closeSheet(Key inside) async {
            Navigator.of(tester.element(find.byKey(inside))).pop();
            await tester.pumpAndSettle();
          }

          if (who == 'trainee') {
            // Today: checking in shows at once, with no signal.
            expect(find.byKey(const Key('check-in')), findsOneWidget);
            if (shots) await _save(tester, boundary, 'today-$tag');
            await tester.tap(find.byKey(const Key('check-in')));
            await tester.pumpAndSettle();
            expect(find.byKey(const Key('check-out')), findsOneWidget);
            expect(logbook.pendingCount.value, 1);
            if (shots) await _save(tester, boundary, 'checked-in-$tag');
            // The job sheet: finishing a job is one tap more.
            await tester.tap(find.text('Front brake pads'));
            await tester.pumpAndSettle();
            expect(find.byKey(const Key('finish-job')), findsOneWidget);
            if (shots) await _save(tester, boundary, 'job-$tag');
            await tester.tap(find.byKey(const Key('minutes-more')));
            await tester.pump();
            await tester.tap(find.byKey(const Key('finish-job')));
            await tester.pumpAndSettle();
            // The job and its two skills, on top of the check-in.
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
            await tester.pumpAndSettle();
            expect(logbook.jobs['job-1']!.status, JobStatus.done);
            expect(logbook.jobs['job-1']!.minutes, 75);
            expect(logbook.recordOf(trainee, 'brakes.inspect')!.note, contains('2014 Corolla'));
            expect(logbook.pendingCount.value, 4);

            await tab(1);
            await tester.runAsync(() => logbook.practise('service.fluids', 'Topped up coolant'));
            await tester.pumpAndSettle();
            expect(logbook.pendingCount.value, 5);
            if (shots) await _save(tester, boundary, 'trainee-$tag');
            await tester.tap(find.byIcon(Icons.replay).first);
            await tester.pumpAndSettle();
            expect(find.byKey(const Key('log-practice')), findsOneWidget);
            if (shots) await _save(tester, boundary, 'sheet-$tag');
            await closeSheet(const Key('log-practice'));

            await tab(2);
            expect(find.byKey(const Key('hours-workshop')), findsOneWidget);
            if (shots) await _save(tester, boundary, 'hours-$tag');
          }
          if (who == 'supervisor') {
            if (shots) await _save(tester, boundary, 'supervisor-$tag');
            await tester.tap(find.byKey(const ValueKey('skill-$trainee/brakes.pads')));
            await tester.pumpAndSettle();
            expect(find.byKey(const Key('sign-off')), findsOneWidget);
            if (shots) await _save(tester, boundary, 'review-$tag');
            await closeSheet(const Key('sign-off'));

            await tester.tap(find.text('Oil and filter change'));
            await tester.pumpAndSettle();
            expect(find.byKey(const Key('check-job')), findsOneWidget);
            if (shots) await _save(tester, boundary, 'check-job-$tag');
            await tester.tap(find.byKey(const Key('minutes-less')));
            await tester.pump();
            await tester.tap(find.byKey(const Key('check-job')));
            await tester.pumpAndSettle();
            expect(logbook.jobs['job-2']!.status, JobStatus.checked);
            expect(logbook.jobs['job-2']!.checkedMinutes, 30);

            await tester.tap(find.byKey(const ValueKey('shift-shift-2')));
            await tester.pumpAndSettle();
            expect(find.byKey(const Key('confirm-shift')), findsOneWidget);
            if (shots) await _save(tester, boundary, 'shift-$tag');
            await tester.tap(find.byKey(const Key('confirm-shift')));
            await tester.pumpAndSettle();
            expect(logbook.shifts['shift-2']!.confirmed, isTrue);
            expect(logbook.hoursOf(trainee).workshop, const Duration(hours: 15, minutes: 30));

            await tab(1);
            expect(find.byKey(const Key('give-job')), findsOneWidget);
            if (shots) await _save(tester, boundary, 'jobs-$tag');
            await tester.tap(find.byKey(const Key('give-job')));
            await tester.pumpAndSettle();
            expect(find.byKey(const Key('save-job')), findsOneWidget);
            if (shots) await _save(tester, boundary, 'give-job-$tag');
            Navigator.of(tester.element(find.byKey(const Key('save-job')))).pop();
            await tester.pumpAndSettle();

            await tab(2);
            if (shots) await _save(tester, boundary, 'trainees-$tag');
          }
          if (who == 'new' && shots) await _save(tester, boundary, 'new-$tag');
          await tester.pumpWidget(const SizedBox.shrink());
          Get.find<LogbookController>().onClose();
          Get.reset();
        });
      }
    }
  }
}

Future<void> _save(WidgetTester tester, GlobalKey boundary, String name) => tester.runAsync(() async {
  final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await render.toImage(pixelRatio: 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  Directory('.shots').createSync();
  File('.shots/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
});
