import '../../tournaments/domain/tournament_models.dart';
import '../domain/challonge_tournament.dart';
import '../domain/community.dart';
import '../domain/community_member_identity.dart';
import 'challonge_native_import.dart';

class ChallongeImportService {
  ChallongeImportService({
    required this.loadMembers,
    required this.createMember,
    required this.loadTournaments,
    required this.saveTournament,
    this.authorizeMemberCreation,
  });
  final Future<List<CommunityMember>> Function() loadMembers;
  final Future<CommunityMember> Function(String name) createMember;
  final Future<List<CreatedTournament>> Function() loadTournaments;
  final Future<void> Function(CreatedTournament tournament) saveTournament;
  final Future<void> Function()? authorizeMemberCreation;
  static List<CommunityMember> matching(
    String name,
    List<CommunityMember> members,
  ) => effectiveCommunityMembers(members)
      .where(
        (m) =>
            m.playerProfileId != null &&
            ChallongeTournament.normalizedName(m.displayName) ==
                ChallongeTournament.normalizedName(name),
      )
      .toList();

  Future<int> import(
    String communityId,
    List<ChallongeTournament> sources, {
    Map<String, String> assignments = const {},
    bool countsForRanking = false,
    bool useNativeLogic = false,
    List<String> rankingIds = const [],
    void Function(String)? progress,
  }) async {
    if (countsForRanking && rankingIds.isEmpty) {
      throw const FormatException(
        'Für die Elo-Wertung mindestens eine Rangliste auswählen.',
      );
    }
    final members = effectiveCommunityMembers(await loadMembers()).toList();
    final existing = (await loadTournaments())
        .where(
          (t) => !useNativeLogic || t.importedArchive?.usesNativeLogic != false,
        )
        .map((t) => t.id)
        .toSet();
    final pending = {for (final t in sources) t.id: t}.values
        .where((t) => !existing.contains(t.tournamentId(communityId)))
        .toList();
    var needsMembers = false;
    // Validate every assignment before creating the first member.
    for (final t in pending) {
      if (useNativeLogic) {
        ChallongeNativeImport.convert(
          t.convert(communityId, {
            for (final p in t.participants)
              '${p['id']}': 'preflight-${p['id']}',
          }),
        );
      }
      final used = <String>{};
      for (final p in t.participants) {
        final name = ChallongeTournament.name(p);
        final key = ChallongeTournament.normalizedName(name);
        final explicit = assignments[key];
        final matches = matching(name, members);
        if (explicit == null && matches.length > 1) {
          throw StateError(
            'Mehrere Mitglieder heißen $name. Bitte eindeutig zuordnen.',
          );
        }
        if (explicit != null &&
            !members.any((m) => m.playerProfileId == explicit)) {
          throw StateError(
            'Mitglied für $name ist nicht mehr vorhanden. Vorschau neu laden.',
          );
        }
        final identity =
            explicit ?? matches.firstOrNull?.playerProfileId ?? 'new:$key';
        if (explicit == null && matches.isEmpty) needsMembers = true;
        if (!used.add(identity)) {
          throw StateError(
            'Zwei Teilnehmer dürfen nicht dasselbe Mitglied verwenden.',
          );
        }
      }
    }
    if (needsMembers) await authorizeMemberCreation?.call();
    var count = 0;
    for (final t in pending) {
      progress?.call('Importiere ${t.title} …');
      final profiles = <String, String>{};
      for (final p in t.participants) {
        final name = ChallongeTournament.name(p);
        final explicit = assignments[ChallongeTournament.normalizedName(name)];
        var member = explicit == null
            ? matching(name, members).firstOrNull
            : members.firstWhere((m) => m.playerProfileId == explicit);
        if (member == null) {
          member = await createMember(name);
          members.add(member);
        }
        profiles['${p['id']}'] = member.playerProfileId!;
      }
      final converted = t.convert(
        communityId,
        profiles,
        countsForRanking: countsForRanking,
        rankingIds: rankingIds,
      );
      await saveTournament(
        useNativeLogic ? ChallongeNativeImport.convert(converted) : converted,
      );
      count++;
    }
    return count;
  }
}
