import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dart_tournament_manager/features/communities/data/community_access_repository.dart';
import 'package:dart_tournament_manager/features/communities/data/supabase_community_repository.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_permissions.dart';
import 'package:dart_tournament_manager/features/communities/domain/community.dart';

class RolePreviewAccess extends CommunityAccessRepository {
  @override
  Future<CommunityPermissions> permissions(String id) async =>
      CommunityPermissions(CommunityPermission.values.map((p) => p.key));
  @override
  Future<List<CommunityRole>> roles(String id) async => [
    CommunityRole(
      id: 'role',
      name: 'Turnierleitung und Geräteverwaltung',
      permissions: ['lead_tournaments', 'assign_devices'],
    ),
  ];
  @override
  Future<Map<String, String>> assignments(String id) async => {
    'member': 'role',
  };
}

class RolePreviewMembers extends SupabaseCommunityRepository {
  RolePreviewMembers()
    : super(
        client: SupabaseClient(
          'https://example.test',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  @override
  Future<List<CommunityMember>> loadMembers(String id) async => [
    CommunityMember(
      userId: 'member',
      displayName: 'Mitglied mit einem längeren deutschen Namen',
      role: 'member',
      joinedAt: DateTime(2026),
    ),
  ];
}
