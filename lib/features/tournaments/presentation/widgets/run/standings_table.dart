import 'package:flutter/material.dart';

import '../../../domain/tournament_models.dart';
import '../../../domain/engines/qualification_certainty.dart';
import '../../../modes/swiss/swiss_engine.dart';

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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final sureColor = isDarkMode ? const Color(0xFF144D34) : const Color(0xFF0B6B45);
    final possibleColor = isDarkMode ? const Color(0xFF163828) : const Color(0xFFD6F5E3);
    final bestOfColor = isDarkMode ? const Color(0xFF3B3216) : const Color(0xFFFFF1C2);

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          horizontalMargin: 12,
          headingRowHeight: 36,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 44,
          columns: [
            const DataColumn(label: Text('#')),
            const DataColumn(label: Text('Spieler')),
            const DataColumn(label: Text('Sp')),
            const DataColumn(label: Text('S')),
            const DataColumn(label: Text('U')),
            const DataColumn(label: Text('N')),
            const DataColumn(label: Text('Legs')),
            const DataColumn(label: Text('Diff')),
            const DataColumn(label: Text('Pkt')),
            if (group.playType == 'swiss')
              const DataColumn(
                label: Tooltip(
                  message: 'Summe der Punkte der gespielten Gegner; Freilose zählen nicht mit.',
                  child: Text('Buchholz'),
                ),
              ),
          ],
          rows: [
            for (var index = 0; index < standings.length; index++)
              _buildRow(
                context: context,
                index: index,
                isDarkMode: isDarkMode,
                sureColor: sureColor,
                possibleColor: possibleColor,
                bestOfColor: bestOfColor,
              ),
          ],
        ),
      ),
    );
  }

  DataRow _buildRow({
    required BuildContext context,
    required int index,
    required bool isDarkMode,
    required Color sureColor,
    required Color possibleColor,
    required Color bestOfColor,
  }) {
    final place = index + 1;
    final standing = standings[index];
    final isFixed = _isFixedQualificationPlace(place);
    final isSure = isFixed && _isSureQualification(standing, place);
    final isPossible = isFixed && !isSure;
    final isBestOf = _isBestOfCandidatePlace(place);

    Color? rowColor;
    Color? cellTextColor;
    FontWeight? fontWeight;

    if (isSure) {
      rowColor = sureColor;
      cellTextColor = isDarkMode ? const Color(0xFF86EFAC) : Colors.white;
      fontWeight = FontWeight.w600;
    } else if (isPossible) {
      rowColor = possibleColor;
      cellTextColor = isDarkMode ? const Color(0xFFA7F3D0) : const Color(0xFF064E3B);
      fontWeight = FontWeight.w500;
    } else if (isBestOf) {
      rowColor = bestOfColor;
      cellTextColor = isDarkMode ? const Color(0xFFFDE68A) : const Color(0xFF78350F);
      fontWeight = FontWeight.w500;
    }

    return DataRow(
      color: WidgetStateProperty.resolveWith((states) => rowColor),
      cells: [
        DataCell(_StandingText('${index + 1}', textColor: cellTextColor, fontWeight: fontWeight)),
        DataCell(_StandingText(standing.player.name, textColor: cellTextColor, fontWeight: fontWeight)),
        DataCell(_StandingText('${standing.played}', textColor: cellTextColor, fontWeight: fontWeight)),
        DataCell(_StandingText('${standing.wins}', textColor: cellTextColor, fontWeight: fontWeight)),
        DataCell(_StandingText('${standing.draws}', textColor: cellTextColor, fontWeight: fontWeight)),
        DataCell(_StandingText('${standing.losses}', textColor: cellTextColor, fontWeight: fontWeight)),
        DataCell(_StandingText('${standing.legsFor}:${standing.legsAgainst}', textColor: cellTextColor, fontWeight: fontWeight)),
        DataCell(_StandingText('${standing.legDifference}', textColor: cellTextColor, fontWeight: fontWeight)),
        DataCell(_StandingText('${standing.points}', textColor: cellTextColor, fontWeight: fontWeight)),
        if (group.playType == 'swiss')
          DataCell(_StandingText(
            '${SwissEngine.buchholz(group, standing.player, standings)}',
            textColor: cellTextColor,
            fontWeight: fontWeight,
          )),
      ],
    );
  }
}

class _StandingText extends StatelessWidget {
  const _StandingText(this.text, {this.textColor, this.fontWeight});

  final String text;
  final Color? textColor;
  final FontWeight? fontWeight;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: textColor,
        fontWeight: fontWeight,
      ),
    );
  }
}
