import 'role.dart';

/// One person in one workshop, with their role there.
class Membership {
  const Membership({required this.workshopId, required this.workshopName, required this.userId, required this.role, required this.displayName});

  factory Membership.fromJson(Map<String, Object?> json) {
    final workshop = json['workshops'] as Map<String, Object?>?;
    return Membership(
      workshopId: json['workshop_id']! as String,
      workshopName: (workshop?['name'] ?? json['workshop_name'] ?? '') as String,
      userId: json['user_id']! as String,
      role: Role.fromName(json['role'] as String?) ?? Role.trainee,
      displayName: json['display_name']! as String,
    );
  }

  final String workshopId;
  final String workshopName;
  final String userId;
  final Role role;
  final String displayName;

  Map<String, Object?> toJson() => {
    'workshop_id': workshopId,
    'workshop_name': workshopName,
    'user_id': userId,
    'role': role.name,
    'display_name': displayName,
  };

  @override
  bool operator ==(Object other) =>
      other is Membership &&
      other.workshopId == workshopId &&
      other.workshopName == workshopName &&
      other.userId == userId &&
      other.role == role &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(workshopId, workshopName, userId, role, displayName);
}
