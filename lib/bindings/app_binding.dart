import 'package:get/get.dart';

import '../controllers/logbook_controller.dart';
import '../controllers/session_controller.dart';
import '../controllers/workshop_controller.dart';
import '../services/auth_service.dart';
import '../services/local_store.dart';
import '../services/logbook_service.dart';
import '../services/workshop_service.dart';

/// Registers the services and controllers. The only place that decides which implementation the app runs on:
/// main.dart passes the Neon ones and the phone's storage.
class AppBinding extends Bindings {
  AppBinding({required this.auth, required this.workshops, required this.logbook, required this.store});

  final AuthService auth;
  final WorkshopService workshops;
  final LogbookService logbook;
  final LocalStore store;

  @override
  void dependencies() {
    final session = SessionController(auth);
    Get
      ..put<AuthService>(auth)
      ..put<WorkshopService>(workshops)
      ..put<LogbookService>(logbook)
      ..put<LocalStore>(store)
      ..put(session)
      ..put(WorkshopController(workshops, store, session))
      ..put(LogbookController(logbook, store));
  }
}
