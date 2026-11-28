import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'bindings/app_binding.dart';
import 'config/env.dart';
import 'config/errors.dart';
import 'platform/http_client.dart';
import 'platform/prefs_store.dart';
import 'services/auth_service.dart';
import 'services/logbook_service.dart';
import 'services/neon_data.dart';
import 'services/workshop_service.dart';

/// Reads the build's addresses, opens the session kept on the phone, and starts the app on the Neon project. A build
/// without addresses shows why instead. It needs no signal to start: the session and the logbook are kept on the phone.
/// Every error nothing else caught goes to the build's reporter (lib/config/errors.dart). Routes, themes and text live
/// in lib/config and lib/l10n, not here.
void main() => runReportingErrors(() async {
  const env = Env.current;
  final problem = env.problem;
  if (problem != null) return runApp(StartupProblem(problem));
  final store = PrefsStore(SharedPreferencesAsync());
  final http = platformHttpClient();
  final auth = NeonAuthService(baseUrl: env.authUrl.trim(), client: http, store: store, origin: isBrowser ? null : env.appOrigin.trim());
  await auth.restore();
  final data = NeonData(url: env.dataUrl.trim(), token: auth.accessToken, httpClient: http);
  runApp(
    MihnaApp(
      binding: AppBinding(auth: auth, workshops: NeonWorkshopService(data), logbook: NeonLogbookService(data), store: store),
    ),
  );
});
