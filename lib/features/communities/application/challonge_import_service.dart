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
    this.createGuestMember,
    this.authorizeMemberCreation,
    this.memberNameMappings = const {},
  });
  final Future<List<CommunityMember>> Function() loadMembers;
  final Future<CommunityMember> Function(String name) createMember;
  final Future<CommunityMember> Function(String name)? createGuestMember;
  final Future<List<CreatedTournament>> Function() loadTournaments;
  final Future<void> Function(CreatedTournament tournament) saveTournament;
  final Future<void> Function()? authorizeMemberCreation;
  final Map<String, String> memberNameMappings;

  /// Maps masked Challonge labels to the real community identity. If that
  /// identity is a guest today, linking the guest to an account later keeps
  /// all imported results under the same Elo identity.
  static const challongeMemberNames = <String, String>{
    'Markus_D': 'Markus Dämgen',
    'Marvin_S': 'Marvin Stelkyte',
    'Steve_T': 'Steven Tittel',
    'Timo_S': 'Timo Schäfer',
    'Jan_Wa': 'Jan Wald',
    'Andre_Wi': 'Andre Wilke',
    'Paddi_Kaspar': 'Patrick Kaspar',
    'Christian_K': 'Christian Klein',
    'Max_Re': 'Maximilian Reusch',
    'Jonas_B': 'Jonas Bung',
    'Tobi_Be': 'Tobias Beitz',
    'KKKEVIN_Tsrik': 'Kevin Kirst',
    'Kevin_noXSSXon': 'Kevin Kirst',
    'Mike_Ro': 'Michael Rockenbach',
    'Dietmar_S': 'Dietmar Schneider',
    'Daniel_Kü': 'Daniel Kühnreich',
    'Timo_B': 'Timo Brochhagen',
    'Friedel_D': 'Friedel Dämgen',
    'Burkhard_H': 'Burkhard Henn',
    'Bernd_R': 'Bernd Rau',
    'johannes_r': 'Johannes Rau',
    'Michael_Le': 'Michael Lemmer',
    'Juan_B': 'Juan Beitz',
    'Alex_Sc': 'Alexander Schinko',
    'Yannick_L': 'Yannick Lorenz',
  };

  static String realMemberName(
    String challongeName, {
    Map<String, String> nameMappings = const {},
  }) {
    final normalized = ChallongeTournament.normalizedName(challongeName);
    return nameMappings.entries
            .where(
              (entry) =>
                  ChallongeTournament.normalizedName(entry.key) == normalized,
            )
            .map((entry) => entry.value)
            .firstOrNull ??
        challongeName.trim();
  }

  static List<CommunityMember> matching(
    String name,
    List<CommunityMember> members, {
    Map<String, String> nameMappings = const {},
  }) {
    final effective = effectiveCommunityMembers(members).where(
      (m) => m.playerProfileId != null,
    );
    final realName = realMemberName(name, nameMappings: nameMappings);
    final normalizedRealName = ChallongeTournament.normalizedName(realName);
    final matches = effective
        .where(
          (m) =>
              ChallongeTournament.normalizedName(m.displayName) ==
              normalizedRealName,
        )
        .toList();
    if (matches.isNotEmpty) return matches;

    // The owner was supplied as "Marv" while the Challonge identity maps to
    // the full real name. Use the unique owner account in that one case.
    if (normalizedRealName != ChallongeTournament.normalizedName(name) &&
        normalizedRealName == ChallongeTournament.normalizedName('Marvin Stelkyte')) {
      final marv = effective
          .where(
            (m) =>
                ChallongeTournament.normalizedName(m.displayName) ==
                ChallongeTournament.normalizedName('Marv'),
          )
          .toList();
      if (marv.isNotEmpty) return marv;
      return effective.where((m) => m.role.toLowerCase() == 'owner').toList();
    }
    return [];
  }

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
    var needsGuests = false;
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
        final matches = matching(
          name,
          members,
          nameMappings: memberNameMappings,
        );
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
            explicit ??
            matches.firstOrNull?.playerProfileId ??
            'new:${ChallongeTournament.normalizedName(realMemberName(name, nameMappings: memberNameMappings))}';
        if (explicit == null && matches.isEmpty) {
          final mappedName = realMemberName(
            name,
            nameMappings: memberNameMappings,
          );
          final knownPlayer = ChallongeTournament.normalizedName(mappedName) !=
              ChallongeTournament.normalizedName(name);
          if (!knownPlayer && createGuestMember != null) {
            needsGuests = true;
          } else {
            needsMembers = true;
          }
        }
        if (!used.add(identity)) {
          throw StateError(
            'Zwei Teilnehmer dürfen nicht dasselbe Mitglied verwenden.',
          );
        }
      }
    }
    if (needsMembers) await authorizeMemberCreation?.call();
    if (needsGuests && createGuestMember == null) {
      await authorizeMemberCreation?.call();
    }
    var count = 0;
    for (final t in pending) {
      progress?.call('Importiere ${t.title} …');
      final profiles = <String, String>{};
      for (final p in t.participants) {
        final name = ChallongeTournament.name(p);
        final explicit = assignments[ChallongeTournament.normalizedName(name)];
        var member = explicit == null
            ? matching(
                name,
                members,
                nameMappings: memberNameMappings,
              ).firstOrNull
            : members.firstWhere((m) => m.playerProfileId == explicit);
        if (member == null) {
          final mappedName = realMemberName(
            name,
            nameMappings: memberNameMappings,
          );
          final isKnownPlayer =
              ChallongeTournament.normalizedName(mappedName) !=
              ChallongeTournament.normalizedName(name);
          member = isKnownPlayer || createGuestMember == null
              ? await createMember(mappedName)
              : await createGuestMember!(mappedName);
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
