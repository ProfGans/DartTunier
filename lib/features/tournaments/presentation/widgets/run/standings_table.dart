import 'package:flutter/material.dart';

import '../../../domain/tournament_models.dart';
import '../../../domain/engines/qualification_certainty.dart';

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

  bool _isSureQualification(PlayerStanding standing, int place) {
    final plan = qualificationPlan;
    if (plan == null) return false;
    final groupIndex = groupNumber - 1;
    final fixedPlaces = groupIndex >= 0 && groupIndex < plan.fixedByGroup.length
        ? plan.fixedByGroup[groupIndex] : plan.fixedPerGroup;
    return const QualificationCertainty().isCertain(
      standing: standing, place: place, fixedPlaces: fixedPlaces,
      standings: standings, matches: group.matches, tieBreakers: tieBreakers,
    );
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
