import 'community.dart';

/// Resolve manual player IDs to their account without rewriting old matches.
List<CommunityMember> effectiveCommunityMembers(List<CommunityMember> members) {
  final accounts = {
    for (final member in members)
      if (member.userId != null) member.userId!: member,
  };
  return [
    for (final member in members)
      if (!member.isManual || !accounts.containsKey(member.linkedUserId))
        CommunityMember(
          userId: member.userId,
          playerProfileId: member.playerProfileId,
          displayName: member.displayName,
          role: member.role,
          joinedAt: member.joinedAt,
          linkedUserId: member.linkedUserId,
          aliasProfileIds: [
            ...member.aliasProfileIds,
            if (member.userId != null)
              for (final guest in members)
                if (guest.isManual &&
                    guest.linkedUserId == member.userId &&
                    guest.playerProfileId != null)
                  guest.playerProfileId!,
          ],
        ),
  ];
}
