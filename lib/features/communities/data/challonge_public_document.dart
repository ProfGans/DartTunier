import 'dart:convert';
import 'package:html/parser.dart' as html;
import '../domain/challonge_tournament.dart';

/// Normalizes Challonge's public bracket store without executing page scripts.
class ChallongePublicDocument {
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

    void addMatch(dynamic value, String? group) {
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
        'started_at': value['underway_at'],
        'completed_at': value['completed_at'],
      };
    }

    void bracket(Map b, String? group) {
      for (final round in (b['matches_by_round'] as Map? ?? const {}).values) {
        for (final m in round as List) {
          addMatch(m, group);
        }
      }
      addMatch(b['third_place_match'], group);
      for (final m in b['consolation_matches'] as List? ?? const []) {
        addMatch(m, group);
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
        final cell = cells[1].clone(true);
        for (final label in cell.querySelectorAll('.label')) {
          label.remove();
        }
        final p = players[ChallongeTournament.normalizedName(cell.text)];
        if (p == null) {
          throw const FormatException(
            'Teilnehmer ohne öffentliche Spielkennung. Vollständigen Export verwenden.',
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
    for (final row in ranks.querySelectorAll('table.standings tbody tr')) {
      final cell = row.querySelector('td.display_name');
      final rank = int.tryParse(
        row.querySelector('td.rank')?.text.trim() ?? '',
      );
      if (cell == null || rank == null) continue;
      final p = players[ChallongeTournament.normalizedName(cell.text)];
      if (p == null) {
        throw const FormatException(
          'Platzierung verweist auf einen unbekannten Teilnehmer.',
        );
      }
      p['final_rank'] = rank;
    }
    if (!players.values.any((p) => p['final_rank'] != null)) {
      throw const FormatException(
        'Die offiziellen Endplatzierungen konnten nicht gelesen werden.',
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
