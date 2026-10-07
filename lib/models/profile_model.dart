class ProfileModel {
  final String id;
  final String? email;
  final String? fullName;
  final String? avatarUrl;
  final String role;

  ProfileModel({
    required this.id,
    this.email,
    this.fullName,
    this.avatarUrl,
    required this.role,
  });

  bool get isAdmin => role == 'admin' || role == 'superuser';

  ProfileModel copyWith({
    String? email,
    String? fullName,
    String? avatarUrl,
    String? role,
  }) {
    return ProfileModel(
      id: id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
    );
  }

  factory ProfileModel.fromMap(Map<String, dynamic> map) => ProfileModel(
        id: map['id'] as String,
        email: map['email'] as String?,
        fullName: map['full_name'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        role: (map['role'] as String?) ?? 'user',
      );
}
