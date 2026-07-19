class AccountUser {
  const AccountUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.lastLogin,
    required this.isActive,
  });

  final String id;
  final String username;
  final String displayName;
  final String email;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLogin;
  final bool isActive;

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}
