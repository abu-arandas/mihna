import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'bindings/app_binding.dart';
import 'config/env.dart';
import 'config/errors.dart';
import 'platform/prefs_store.dart';
import 'services/auth_service.dart';
import 'services/logbook_service.dart';
import 'services/workshop_service.dart';

/// Reads the build's keys, opens Supabase, and starts the app on it. A build without keys, or a server that does not
/// answer, shows why instead. Every error nothing else caught goes to the build's reporter (lib/config/errors.dart).
/// Routes, themes and text live in lib/config and lib/l10n, not here.
void main() => runReportingErrors(() async {
  const env = Env.current;
  final problem = env.problem;
  if (problem != null) return runApp(StartupProblem(problem));
  try {
    await Supabase.initialize(url: env.supabaseUrl, publishableKey: env.supabaseKey).timeout(const Duration(seconds: 30));
  } catch (_) {
    return runApp(const StartupProblem('The server did not answer. Check the connection and reload.'));
  }
  final client = Supabase.instance.client;
  runApp(
    MihnaApp(
      binding: AppBinding(
        auth: SupabaseAuthService(client),
        workshops: SupabaseWorkshopService(client),
        logbook: SupabaseLogbookService(client),
        store: PrefsStore(SharedPreferencesAsync()),
        authRedirectUrl: env.authRedirectUrl,
      ),
    ),
  );
});
