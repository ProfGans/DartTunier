enum CommunityPermission {
  manageRoles('manage_roles', 'Rollen erstellen und zuweisen'),
  createTournaments('create_tournaments', 'Turniere erstellen'),
  inviteMembers('invite_members', 'Mitgliedereinladungslink teilen'),
  deleteTournaments('delete_tournaments', 'Turniere löschen'),
  editTournaments('edit_tournaments', 'Turniere bearbeiten'),
  removeMembers('remove_members', 'Mitglieder entfernen'),
  assignDevices('assign_devices', 'Geräte zuteilen'),
  leadTournaments('lead_tournaments', 'Turniere leiten'),
  editCommunity('edit_community', 'Community bearbeiten'),
  manageRankings('manage_rankings', 'Ranglisten verwalten'),
  manageHighlights('manage_highlights', 'Highlights verwalten');

  const CommunityPermission(this.key, this.label);
  final String key;
  final String label;
}

class CommunityPermissions {
  CommunityPermissions(Iterable<String> keys) : keys = Set.unmodifiable(keys);
  final Set<String> keys;
  bool allows(CommunityPermission permission) => keys.contains(permission.key);
  bool mayGrant(Iterable<String> permissions) =>
      allows(CommunityPermission.manageRoles) && keys.containsAll(permissions);
}

class CommunityRole {
  const CommunityRole({
    required this.id,
    required this.name,
    required this.permissions,
  });
  final String id;
  final String name;
  final List<String> permissions;
  factory CommunityRole.fromJson(Map<String, dynamic> json) => CommunityRole(
    id: json['id'] as String,
    name: json['name'] as String,
    permissions: List<String>.from(json['permissions'] as List),
  );
}
