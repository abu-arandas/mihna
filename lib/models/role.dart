/// What a person does in a workshop. The database checks it on every write (supabase/migrations).
enum Role {
  /// Logs the skills they practised.
  trainee,

  /// Signs practised skills off, or sends them back with a note.
  supervisor,

  /// Runs the workshop's people, and can sign off too.
  admin;

  /// The role a database row names, or null for one this build does not know.
  static Role? fromName(String? name) => Role.values.where((r) => r.name == name).firstOrNull;

  /// Supervisors and admins review; trainees do not.
  bool get reviews => this != trainee;
}
