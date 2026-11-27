import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentry/sentry.dart';

import 'brand.dart';
import 'env.dart';

/// Where an error nothing else caught is sent: [SentryErrorReporter] when the build was given a Sentry address, else
/// [LogErrorReporter] (see [errorReporter]). Another service (Crashlytics, the product's own endpoint) implements this
/// once and is returned by [errorReporter].
abstract interface class ErrorReporter {
  void report(Object error, StackTrace? stack, {String? context});
}

/// Writes the error to the developer log (the browser console on the web), and nowhere else.
class LogErrorReporter implements ErrorReporter {
  const LogErrorReporter();

  @override
  void report(Object error, StackTrace? stack, {String? context}) =>
      developer.log(context ?? 'Uncaught error', name: Brand.slug, error: error, stackTrace: stack, level: 1000);
}

/// Sends the error to the build's Sentry project, and still writes it to the developer log.
///
/// Sentry gets the error, its stack, the page and the browser or device, never who is signed in (`sendDefaultPii`
/// stays off). It also sees the sender's IP address, which the project keeps unless its "Prevent Storing of IP
/// Addresses" setting is on (docs/DEPLOY.md).
class SentryErrorReporter implements ErrorReporter {
  const SentryErrorReporter();

  @override
  void report(Object error, StackTrace? stack, {String? context}) {
    const LogErrorReporter().report(error, stack, context: context);
    Sentry.captureException(error, stackTrace: stack, message: context == null ? null : SentryMessage(context));
  }
}

/// The reporter this build uses. A build given `--dart-define=SENTRY_DSN=<the project's DSN>` reports to Sentry
/// (with `SENTRY_RELEASE`, the commit, when given); without it, errors only go to the developer log.
Future<ErrorReporter> errorReporter() async {
  final dsn = Env.sentryDsn.trim();
  if (dsn.isEmpty) return const LogErrorReporter();
  final release = Env.sentryRelease.trim();
  await Sentry.init((options) {
    options
      ..dsn = dsn
      ..environment = kReleaseMode ? 'production' : 'debug'
      ..release = release.isEmpty ? null : '${Brand.slug}@$release';
  });
  return const SentryErrorReporter();
}

/// Runs [app] so that every error nothing else caught reaches the build's reporter ([errorReporter]): those thrown
/// while a screen is built or drawn ([FlutterError.onError]) and those thrown in code that runs later, such as a timer
/// or a reply from the server. A device hands the later ones to [PlatformDispatcher.onError]; a browser only to the
/// zone the app runs in, so the app runs in one. In a release build, a part of a screen that fails to build shows a
/// quiet notice in its place instead of Flutter's grey box ([quietErrorWidget]); debug builds keep Flutter's red one.
void runReportingErrors(Future<void> Function() app) {
  ErrorReporter reporter = const LogErrorReporter();
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    reporter = await errorReporter();
    final flutterDefault = FlutterError.onError;
    FlutterError.onError = (details) {
      reporter.report(details.exception, details.stack, context: details.context?.toDescription());
      if (kDebugMode) flutterDefault?.call(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      reporter.report(error, stack);
      return true;
    };
    if (kReleaseMode) ErrorWidget.builder = quietErrorWidget;
    await app();
  }, (error, stack) => reporter.report(error, stack));
}

/// What a part of a screen that failed to build shows in a release build: a small notice in the theme's secondary
/// text colour, in the page's language and direction, that does not break the layout around it.
Widget quietErrorWidget(FlutterErrorDetails details) => Builder(
  builder: (context) {
    final colour = Theme.of(context).colorScheme.onSurfaceVariant;
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 18, color: colour),
              const SizedBox(width: 8),
              Flexible(
                child: Text('Something went wrong here.'.tr, style: TextStyle(color: colour, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  },
);
