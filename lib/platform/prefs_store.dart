import 'package:shared_preferences/shared_preferences.dart';

import '../services/local_store.dart';

/// [LocalStore] on the phone's own storage (the browser's local storage on the web). It is the one platform piece
/// the services need, so it lives here rather than in lib/services, which stays plain Dart (ARCHITECTURE.md).
class PrefsStore implements LocalStore {
  PrefsStore(this._prefs);

  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> read(String key) => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}
