import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../application/scorer_controller.dart';
import '../domain/scorer_settings.dart';
import '../domain/x01/x01_models.dart';

/// Versioned local checkpoint; separate slots for guests and signed-in accounts.
class ScorerDraftStorage {
  String _key(String? accountId) => 'scorer_draft_v1_${accountId ?? 'guest'}';

  Future<Map<String, dynamic>?> load(String? accountId) async {
    final raw = (await SharedPreferences.getInstance()).getString(
      _key(accountId),
    );
    if (raw == null) return null;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['version'] != 1 && data['version'] != 2) {
      throw const FormatException('Unbekannte Spielstand-Version');
    }
    return data;
  }

  Future<void> save(String? accountId, Map<String, dynamic> data) async {
    if (!await (await SharedPreferences.getInstance()).setString(
      _key(accountId),
      jsonEncode(data),
    )) {
      throw StateError('Spielstand konnte nicht gespeichert werden');
    }
  }

  Future<void> removeSession(String? accountId, String sessionId) async {
    final draft = await load(accountId);
    if (draft?['sessionId'] == sessionId) {
      if (!await (await SharedPreferences.getInstance()).remove(
        _key(accountId),
      )) {
        throw StateError('Spielstand konnte nicht entfernt werden');
      }
    }
  }

  static Map<String, dynamic> checkpoint(
    ScorerController controller, {
    required String sessionId,
    required DateTime playedAt,
    int? profilePlayerIndex,
  }) => {
    'version': 2,
    'sessionId': sessionId,
    'playedAt': playedAt.toIso8601String(),
    'profilePlayerIndex': profilePlayerIndex,
    'settings': encodeSettings(controller.settings),
    'actions': controller.exportActions(),
  };

  static Map<String, dynamic> encodeSettings(ScorerSettings s) => {
    'startScore': s.startScore,
    'bestOfLegs': s.bestOfLegs,
    'bestOfSets': s.bestOfSets,
    'startingPlayer': s.startingPlayer,
    'start': s.startRequirement.name,
    'out': s.checkoutRequirement.name,
    'delay': s.botThrowDelay.inMilliseconds,
    'participants': [
      for (final p in s.participants)
        {
          'name': p.name,
          'startScore': p.startScore,
          'accountId': p.accountId,
          'members': p.members,
          'bot': p.bot == null
              ? null
              : {
                  'skill': p.bot!.skill,
                  'finishing': p.bot!.finishingSkill,
                  'radius': p.bot!.radiusCalibrationPercent,
                  'spread': p.bot!.simulationSpreadPercent,
                },
        },
    ],
  };

  static ScorerSettings decodeSettings(Map<String, dynamic> s) =>
      ScorerSettings(
        startScore: s['startScore'] as int,
        bestOfLegs: s['bestOfLegs'] as int,
        bestOfSets: s['bestOfSets'] as int,
        startingPlayer: s['startingPlayer'] as int,
        startRequirement: StartRequirement.values.byName(s['start'] as String),
        checkoutRequirement: CheckoutRequirement.values.byName(
          s['out'] as String,
        ),
        botThrowDelay: Duration(milliseconds: s['delay'] as int),
        participants: [
          for (final p in s['participants'] as List)
            ScorerParticipant(
              p['name'] as String,
              startScore: p['startScore'] as int?,
              accountId: p['accountId'] as String?,
              members: (p['members'] as List).cast<String>(),
              bot: p['bot'] == null
                  ? null
                  : BotProfile(
                      skill: p['bot']['skill'] as int,
                      finishingSkill: p['bot']['finishing'] as int,
                      radiusCalibrationPercent: p['bot']['radius'] as int,
                      simulationSpreadPercent: p['bot']['spread'] as int,
                    ),
            ),
        ],
      );
}
