import 'package:supabase_flutter/supabase_flutter.dart';
import '../../communities/data/community_access_repository.dart';
import '../../communities/data/supabase_community_repository.dart';
import '../domain/tournament_access.dart';
import '../domain/tournament_models.dart';

class TournamentAccessRepository {
  Future<TournamentAccess> load(CreatedTournament tournament) async {
    if (tournament.communityId == null) return TournamentAccess.local;
    final user = Supabase.instance.client.auth.currentUser?.id;
    if (user == null) return const TournamentAccess();
    final rights = await CommunityAccessRepository().permissions(
      tournament.communityId!,
    );
    final members = await SupabaseCommunityRepository().loadMembers(
      tournament.communityId!,
    );
    if (Supabase.instance.client.auth.currentUser?.id != user) {
      return const TournamentAccess();
    }
    return TournamentAccess.resolve(
      tournament.access,
      user,
      rights,
      isMember: members.any((m) => m.userId == user),
    );
  }

  Future<void> requireLead(CreatedTournament t) async {
    if (!(await load(t)).canLead) {
      throw StateError('Keine Turnierleitungsberechtigung.');
    }
  }

  Future<void> requireConfigure(CreatedTournament t) async {
    if (!(await load(t)).canConfigure) {
      throw StateError(
        'Nur Ersteller oder berechtigte Community-Verwalter können die Turnierrechte ändern.',
      );
    }
  }
}
