class Community {
  const Community({
    required this.id,
    required this.name,
    required this.description,
    required this.inviteCode,
    required this.ownerUserId,
    required this.createdAt,
    this.memberCount = 0,
    this.avatarBase64,
    this.rankingEnabled = true,
  });

  final String id;
  final String name;
  final String description;
  final String inviteCode;
  final String ownerUserId;
  final DateTime createdAt;
  final int memberCount;
  final String? avatarBase64;
  final bool rankingEnabled;

  factory Community.fromJson(Map<String, dynamic> json) {
    return Community(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Community',
      description: json['description'] as String? ?? '',
      inviteCode: json['invite_code'] as String? ?? '',
      ownerUserId: json['owner_user_id'] as String,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      memberCount: json['member_count'] as int? ?? 0,
      avatarBase64: json['avatar_base64'] as String?,
      rankingEnabled: json['ranking_enabled'] as bool? ?? true,
    );
  }
}

class CommunityMember {
  const CommunityMember({
    required this.userId,
    this.playerProfileId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
    this.linkedUserId,
    this.aliasProfileIds = const [],
  });

  final String? userId;
  final String? linkedUserId;
  final List<String> aliasProfileIds;
  bool get isManual => userId == null;
  final String? playerProfileId;
  final String displayName;
  final String role;
  final DateTime joinedAt;
}
