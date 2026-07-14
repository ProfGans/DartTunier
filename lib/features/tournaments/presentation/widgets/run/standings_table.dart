import 'package:flutter/material.dart';

import '../../../domain/tournament_models.dart';

class StandingsTable extends StatelessWidget {
  const StandingsTable({
    super.key,
    required this.standings,
    required this.group,
    required this.groupNumber,
    required this.qualificationPlan,
    required this.tieBreakers,
  });

  final List<PlayerStanding> standings;
  final TournamentGroup group;
  final int groupNumber;
  final QualificationPlan? qualificationPlan;
  final List<String> tieBreakers;

  bool get _allMatchesComplete {
    return group.matches.every((match) => match.hasResult);
  }

  bool _isFixedQualificationPlace(int place) {
    final plan = qualificationPlan;
    if (plan == null) {
      return false;
    }

    final fixedForGroup = groupNumber - 1 < plan.fixedByGroup.length
        ? plan.fixedByGroup[groupNumber - 1]
        : plan.fixedPerGroup;
    return place <= fixedForGroup;
  }

  bool _isBestOfCandidatePlace(int place) {
    final plan = qualificationPlan;
    if (plan == null) {
      return false;
    }

    return plan.extraCount > 0 &&
        place == plan.extraRank &&
        plan.extraGroups.contains(groupNumber);
  }

  int _qualificationPlacesInGroup() {
    final plan = qualificationPlan;
    if (plan == null) {
      return 0;
    }

    final fixedForGroup = groupNumber - 1 < plan.fixedByGroup.length
        ? plan.fixedByGroup[groupNumber - 1]
        : plan.fixedPerGroup;
    return fixedForGroup +
        (plan.extraGroups.contains(groupNumber) && plan.extraCount > 0 ? 1 : 0);
  }

  int _remainingMatchesFor(PlayerStanding standing) {
    return group.matches.where((match) {
      if (match.hasResult) {
        return false;
      }

      return match.homePlayer?.name == standing.player.name ||
          match.awayPlayer?.name == standing.player.name;
    }).length;
  }

  bool _isSureQualification(PlayerStanding standing, int place) {
    if (!_isFixedQualificationPlace(place)) {
      return false;
    }

    if (_allMatchesComplete) {
      return true;
    }

    final qualificationPlaces = _qualificationPlacesInGroup();
    if (qualificationPlaces < 1) {
      return false;
    }

    final possibleOvertakers = standings.where((otherStanding) {
      if (otherStanding.player.name == standing.player.name) {
        return false;
      }

      final maxPoints =
          otherStanding.points + (_remainingMatchesFor(otherStanding) * 3);
      if (maxPoints > standing.points) {
        return true;
      }
      if (maxPoints < standing.points) {
        return false;
      }

      return _compareStandingsForTable(otherStanding, standing) < 0;
    }).length;

    return possibleOvertakers < qualificationPlaces;
  }

  int _compareStandingsForTable(PlayerStanding a, PlayerStanding b) {
    for (final tieBreaker in tieBreakers) {
      final comparison = switch (tieBreaker) {
        'points' => b.points.compareTo(a.points),
        'legDifference' => b.legDifference.compareTo(a.legDifference),
        'legsFor' => b.legsFor.compareTo(a.legsFor),
        'headToHead' => _compareHeadToHeadForTable(a, b),
        _ => 0,
      };

      if (comparison != 0) {
        return comparison;
      }
    }

    return a.player.name.compareTo(b.player.name);
  }

  int _compareHeadToHeadForTable(PlayerStanding a, PlayerStanding b) {
    var aPoints = 0;
    var bPoints = 0;
    var aLegs = 0;
    var bLegs = 0;

    for (final match in group.matches.where(
      (match) => match.hasResult && !match.isDecider,
    )) {
      final home = match.homePlayer!;
      final away = match.awayPlayer!;
      final isDirectMatch =
          (home.name == a.player.name && away.name == b.player.name) ||
          (home.name == b.player.name && away.name == a.player.name);
      if (!isDirectMatch) {
        continue;
      }

      final aIsHome = home.name == a.player.name;
      final aMatchLegs = aIsHome ? match.homeLegs! : match.awayLegs!;
      final bMatchLegs = aIsHome ? match.awayLegs! : match.homeLegs!;
      aLegs += aMatchLegs;
      bLegs += bMatchLegs;

      if (aMatchLegs > bMatchLegs) {
        aPoints += 3;
      } else if (bMatchLegs > aMatchLegs) {
        bPoints += 3;
      } else {
        aPoints++;
        bPoints++;
      }
    }

    final pointCompare = bPoints.compareTo(aPoints);
    if (pointCompare != 0) return pointCompare;
    final diffCompare = (bLegs - aLegs).compareTo(aLegs - bLegs);
    if (diffCompare != 0) return diffCompare;
    return bLegs.compareTo(aLegs);
  }

  @override
  Widget build(BuildContext context) {
    final sureColor = const Color(0xFF0B6B45);
    final possibleColor = const Color(0xFFC8F7DC);
    final bestOfColor = const Color(0xFFFFE8A3);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 44,
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('Spieler')),
          DataColumn(label: Text('Sp')),
          DataColumn(label: Text('S')),
          DataColumn(label: Text('U')),
          DataColumn(label: Text('N')),
          DataColumn(label: Text('Legs')),
          DataColumn(label: Text('Diff')),
          DataColumn(label: Text('Pkt')),
        ],
        rows: [
          for (var index = 0; index < standings.length; index++)
            DataRow(
              color: WidgetStateProperty.resolveWith((states) {
                final place = index + 1;
                if (_isFixedQualificationPlace(place)) {
                  return _isSureQualification(standings[index], place)
                      ? sureColor
                      : possibleColor;
                }

                if (_isBestOfCandidatePlace(place)) {
                  return bestOfColor;
                }

                return null;
              }),
              cells: [
                DataCell(
                  _StandingText(
                    '${index + 1}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    standings[index].player.name,
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    '${standings[index].played}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    '${standings[index].wins}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    '${standings[index].draws}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    '${standings[index].losses}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    '${standings[index].legsFor}:${standings[index].legsAgainst}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    '${standings[index].legDifference}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    '${standings[index].points}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StandingText extends StatelessWidget {
  const _StandingText(this.text, {required this.isDark});

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: isDark ? Colors.white : null,
        fontWeight: isDark ? FontWeight.w600 : null,
      ),
    );
  }
}
