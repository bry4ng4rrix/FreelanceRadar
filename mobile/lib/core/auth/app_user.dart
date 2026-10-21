import '../utils/json.dart';

/// Utilisateur connecté (`UserRead` : id, email, is_active, created_at).
class AppUser {
  const AppUser({required this.id, required this.email, required this.isActive, this.createdAt});

  final int id;
  final String email;
  final bool isActive;
  final DateTime? createdAt;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: parseInt(json['id']) ?? 0,
    email: json['email']?.toString() ?? '',
    isActive: json['is_active'] as bool? ?? true,
    createdAt: parseDate(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'is_active': isActive,
    'created_at': createdAt?.toUtc().toIso8601String(),
  };
}
