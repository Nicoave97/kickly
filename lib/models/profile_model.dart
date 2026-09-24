class ProfileModel {
  final String id;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final String preferredRole;
  final DateTime? birthDate;

  const ProfileModel({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    required this.preferredRole,
    this.birthDate,
  });

  factory ProfileModel.fromMap(Map<String, dynamic> map, {DateTime? birthDate}) {
    return ProfileModel(
      id: map['id'] as String,
      username: (map['username'] as String?) ?? '',
      fullName: (map['full_name'] as String?) ?? 'Giocatore',
      avatarUrl: map['avatar_url'] as String?,
      preferredRole: (map['preferred_role'] as String?) ?? 'Non specificato',
      birthDate: birthDate,
    );
  }
}
