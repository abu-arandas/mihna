/// Text kept on the phone between runs: the queue of unsent changes and the last copy of the server's records, so
/// the app opens and works with no signal. Plain Dart: the app hands it the platform's storage (lib/platform).
abstract interface class LocalStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> remove(String key);
}
