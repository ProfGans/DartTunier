import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' show Element;
import '../domain/challonge_tournament.dart';

/// Normalizes Challonge's public bracket store without executing page scripts.
class ChallongePublicDocument {
  static String _participantLabel(Element source) {
    final cell = source.clone(true);
    for (final decoration in cell.querySelectorAll(
      '.label, .badge, .portrait',
    )) {
      decoration.remove();
    }
    final profile = cell.querySelector('a[href*="/users/"]');
    if (profile == null) return cell.text.trim();
    final profileName = profile.text.trim();
    profile.remove();
    final tournamentName = cell.text
        .replaceFirst(RegExp(r'\(\s*\)\s*$'), '')
        .trim();
    return tournamentName.isEmpty ? profileName : tournamentName;
  }

  static Map<String, dynamic>? store(String source) {
    for (final script in html.parse(source).querySelectorAll('script')) {
      final text = script.text;
      final marker = RegExp(
        r'''\[\s*["']TournamentStore["']\s*\]\s*=''',
      ).firstMatch(text);
      if (marker == null) continue;
      final start = text.indexOf('{', marker.end);
      var depth = 0, quoted = false, escaped = false;
      for (var i = start; i >= 0 && i < text.length; i++) {
        final c = text[i];
        if (quoted) {
          if (escaped) {
            escaped = false;
          } else if (c == r'\') {
            escaped = true;
          } else if (c == '"') {
            quoted = false;
          }
        } else {
          if (c == '"') {
            quoted = true;
          } else if (c == '{') {
            depth++;
          } else if (c == '}' && --depth == 0) {
            return Map<String, dynamic>.from(
              jsonDecode(text.substring(start, i + 1)) as Map,
            );
          }
        }
      }
    }
    return null;
  }

  static String? standingsLink(String source) {
    for (final a in html.parse(source).querySelectorAll('a[href]')) {
      final href = a.attributes['href']!;
      if (Uri.tryParse(href)?.path.endsWith('/standings') == true) return href;
    }
    return null;
  }

  static ChallongeTournament convert(
    String source,
    String standings,
    Map<String, dynamic> store,
    Uri uri,
  ) {
    final metadata = Map<String, dynamic>.from(store['tournament'] as Map);
    if (metadata['is_team'] == true ||
        metadata['split_participants'] == true ||
        metadata['participants_per_match'] != 2) {
      throw const FormatException(
        'Dieser öffentliche Turniertyp wird noch nicht unterstützt.',
      );
    }
    final players = <String, Map<String, dynamic>>{};
    final matches = <String, Map<String, dynamic>>{};
    final identities = <String, Map<String, String>>{};
    final groupOwners = <String, String>{};
    void player(dynamic value, String? group) {
      if (value is! Map || value['id'] == null) return;
      final name = '${value['display_name'] ?? ''}'.trim();
      final key = ChallongeTournament.normalizedName(name);
      final scope = identities.putIfAbsent(group ?? 'finals', () => {});
      if (scope.containsKey(key) && scope[key] != '${value['id']}') {
        throw const FormatException(
          'Gleichnamige Teilnehmer können nicht eindeutig zugeordnet werden.',
        );
      }
      scope[key] = '${value['id']}';
      if (group != null) {
        if (groupOwners.containsKey(key) && groupOwners[key] != group) {
          throw const FormatException(
            'Gleichnamige Teilnehmer in verschiedenen Gruppen.',
          );
        }
        groupOwners[key] = group;
      }
      final p = players.putIfAbsent(
        key,
        () => {
          'id': value['id'],
          'name': name,
          'group_player_ids': <dynamic>[],
          'group_placements': <Map<String, dynamic>>[],
        },
      );
      if (p['id'] != value['id'] &&
          !(p['group_player_ids'] as List).contains(value['id'])) {
        (p['group_player_ids'] as List).add(value['id']);
      }
    }

    void addMatch(dynamic value, String? group, String? groupType) {
      if (value is! Map || value['id'] == null) return;
      player(value['player1'], group);
      player(value['player2'], group);
      final games = value['games'] as List? ?? const [];
      final scores = value['scores'] as List? ?? const [];
      final score = games.isNotEmpty
          ? games.map((g) => (g as List).join('-')).join(',')
          : scores.join('-');
      matches['${value['id']}'] = {
        'id': value['id'],
        'identifier': value['identifier'],
        'round': value['round'],
        'state': value['state'],
        'player1_id': value['player1']?['id'],
        'player2_id': value['player2']?['id'],
        'winner_id': value['winner_id'],
        'loser_id': value['loser_id'],
        'scores_csv': score,
        'group_id': group,
        'group_type': groupType,
        'player1_seed': value['player1']?['seed'],
        'player2_seed': value['player2']?['seed'],
        'started_at': value['underway_at'],
        'completed_at': value['completed_at'],
      };
    }

    void bracket(Map b, String? group) {
      final groupType = group == null
          ? null
          : b['tournament']?['tournament_type'] as String?;
      for (final round in (b['matches_by_round'] as Map? ?? const {}).values) {
        for (final m in round as List) {
          addMatch(m, group, groupType);
        }
      }
      addMatch(b['third_place_match'], group, groupType);
      for (final m in b['consolation_matches'] as List? ?? const []) {
        addMatch(m, group, groupType);
      }
    }

    bracket(store, null);
    for (final group in store['groups'] as List? ?? const []) {
      bracket(group as Map, '${group['name']}');
      for (final row
          in html
              .parse('${group['scorecard_html'] ?? ''}')
              .querySelectorAll('tbody tr')) {
        final cells = row.querySelectorAll('td');
        if (cells.length < 2) continue;
        final name = _participantLabel(
          row.querySelector('td.participant') ?? cells[1],
        );
        var p = players[ChallongeTournament.normalizedName(name)];
        // A scorecard's match history also identifies the player when its
        // rendered label differs from the bracket's display name. Require an
        // unambiguous intersection rather than guessing from a similar name.
        if (p == null) {
          Set<String>? candidates;
          for (final link in row.querySelectorAll('[data-match-id]')) {
            final match = matches[link.attributes['data-match-id']];
            if (match == null || match['group_id'] != '${group['name']}') {
              continue;
            }
            final ids = {'${match['player1_id']}', '${match['player2_id']}'};
            candidates = candidates == null
                ? ids
                : candidates.intersection(ids);
          }
          if (candidates?.length == 1) {
            final identified = players.values
                .where(
                  (player) =>
                      '${player['id']}' == candidates!.single ||
                      (player['group_player_ids'] as List).any(
                        (id) => '$id' == candidates!.single,
                      ),
                )
                .toList();
            if (identified.length == 1) p = identified.single;
          }
        }
        if (p == null) {
          throw FormatException(
            'Teilnehmer „${name.trim()}“ in ${group['name']} konnte keiner öffentlichen Spielkennung zugeordnet werden (${uri.toString()}).',
          );
        }
        final rank = int.tryParse(cells.first.text.trim());
        if (rank != null) {
          (p['group_placements'] as List).add({
            'group': group['name'],
            'rank': rank,
          });
        }
      }
    }
    final ranks = html.parse(standings);
    final standaloneStandings =
        (store['groups'] as List? ?? const []).isEmpty &&
        ['swiss', 'round robin'].contains(metadata['tournament_type']);
    for (final row in ranks.querySelectorAll('table.standings tbody tr')) {
      final cells = row.querySelectorAll('td');
      final cell =
          row.querySelector('td.display_name') ??
          (standaloneStandings ? row.querySelector('td.participant') : null);
      final rank = int.tryParse(
        row.querySelector('td.rank')?.text.trim() ??
            (standaloneStandings && cells.isNotEmpty
                ? cells.first.text.trim()
                : ''),
      );
      if (cell == null || rank == null) continue;
      final name = _participantLabel(cell);
      final p = players[ChallongeTournament.normalizedName(name)];
      if (p == null) {
        throw FormatException(
          'Platzierung für „$name“ verweist auf einen unbekannten Teilnehmer (${uri.toString()}).',
        );
      }
      p['final_rank'] = rank;
    }
    if (!players.values.any((p) => p['final_rank'] != null)) {
      throw FormatException(
        'Die offiziellen Endplatzierungen konnten nicht gelesen werden (${uri.toString()}, ${metadata['tournament_type']}).',
      );
    }
    final doc = html.parse(source);
    final title =
        doc
            .querySelector('meta[property="og:title"]')
            ?.attributes['content']
            ?.replaceFirst(RegExp(r' - Challonge$'), '') ??
        'Challonge-Turnier';
    final date = _date(doc.querySelector('.start-time')?.text ?? '');
    if (date == null) {
      throw const FormatException(
        'Das tatsächliche Turnierdatum konnte nicht gelesen werden.',
      );
    }
    return ChallongeTournament({
      ...metadata,
      'name': title,
      'teams': metadata['is_team'],
      'created_at': date,
      'started_at': date,
      'public_dates': true,
      'full_challonge_url': uri.toString(),
      'participants': players.values.toList(),
      'matches': matches.values.toList(),
    });
  }

  static String? _date(String value) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final m = RegExp(
      r'(\w+)\s+(\d+),\s+(\d+)\s+(?:bei|at)\s+(\d+):(\d+)\s+(AM|PM)\s+(CEST|CET|UTC)',
    ).firstMatch(value);
    if (m == null || !months.contains(m[1])) return null;
    final hour = int.parse(m[4]!) % 12 + (m[6] == 'PM' ? 12 : 0);
    final offset = m[7] == 'CEST'
        ? 2
        : m[7] == 'CET'
        ? 1
        : 0;
    return DateTime.utc(
      int.parse(m[3]!),
      months.indexOf(m[1]!) + 1,
      int.parse(m[2]!),
      hour - offset,
      int.parse(m[5]!),
    ).toIso8601String();
  }
}
