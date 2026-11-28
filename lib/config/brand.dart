import 'dart:ui' show Color, Locale;

/// Everything a rebrand changes in the Dart code, in one place. The files that ship outside Dart (the web page's
/// title and icons, the Android and iPhone app names and ids) are listed in docs/REBRAND.md.
class Brand {
  /// The product's name in English, also the translation key for [nameAr].
  static const name = 'Mihna';

  /// The product's name in Arabic.
  static const nameAr = 'مِهنة';

  /// The product's short name in code: the developer log's name, and the prefix of an error report's release
  /// (`mihna@<commit>`), so reports from different products never mix in one Sentry project.
  static const slug = 'mihna';

  /// The colour every screen's palette is made from: Mihna petrol, the deep green of a workshop's tool wall.
  static const seedColor = Color(0xFF1F5F5B);

  /// The one highlight colour (safety amber, as on a hi-vis vest), and its lighter dark-mode shade. Dark text only.
  static const accentColor = Color(0xFFF2A93B);
  static const accentColorDark = Color(0xFFFFC266);

  /// A font bundled in pubspec.yaml, or null for the platform's own. Rubik draws Arabic and Latin in one family.
  static const String fontFamily = 'Rubik';

  /// The trade this build's checklist is for (lib/models/trade.dart). The pilot is auto repair in Amman.
  static const trade = 'auto_repair';

  /// The languages the app speaks. The first is the one it opens in.
  static const locales = [Locale('ar'), Locale('en')];

  /// Whether the sign-in page offers "Create an account". Turn it off for a product whose accounts are made by an
  /// admin, and also turn off sign-up in the project's Neon Auth settings, which is what really stops it.
  static const allowSignUp = true;

  /// The web address the app is served from. Phone builds send it to Neon Auth as their `Origin`, so it must be one of
  /// the project's trusted domains (docs/SETUP.md). A build can give another with `--dart-define=APP_ORIGIN=...`.
  static const appOrigin = 'https://mihna.arandas.tech';
}
