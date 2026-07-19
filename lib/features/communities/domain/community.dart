class Community {
  const Community({
    required this.id,
    required this.name,
    required this.description,
    required this.inviteCode,
    required this.ownerUserId,
    required this.createdAt,
    this.memberCount = 0,
  });

  final String id;
  final String name;
  final String description;
  final String inviteCode;
  final String ownerUserId;
  final DateTime createdAt;
  final int memberCount;

  factory Community.fromJson(Map<String, dynamic> json) {
    return Community(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Community',
      description: json['description'] as String? ?? '',
      inviteCode: json['invite_code'] as String? ?? '',
      ownerUserId: json['owner_user_id'] as String,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      memberCount: json['member_count'] as int? ?? 0,
    );
  }
}

class CommunityMember {
  const CommunityMember({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
  });

  final String userId;
  final String displayName;
  final String role;
  final DateTime joinedAt;
}
