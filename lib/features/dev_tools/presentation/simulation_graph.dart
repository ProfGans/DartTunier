import '../../tournaments/domain/knockout_round_names.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/tournament_simulation_engine.dart';

class SimulationGraph extends StatelessWidget {
  const SimulationGraph({super.key, required this.records});
  final List<SimulationMatchRecord> records;

  @override
  Widget build(BuildContext context) {
    final layout = SimulationGraphLayout(records);
    return SizedBox(height: 560, child: ClipRect(child: InteractiveViewer(
      constrained: false, minScale: .15, maxScale: 2.5,
      boundaryMargin: const EdgeInsets.all(40),
      child: SizedBox(width: layout.width, height: layout.height, child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: SimulationConnections(layout))),
        for (final heading in layout.headings)
          Positioned(left: heading.position.dx, top: heading.position.dy,
            child: Text(heading.text, style: heading.section
              ? Theme.of(context).textTheme.titleLarge
              : Theme.of(context).textTheme.titleSmall)),
        for (final record in records)
          Positioned(left: layout.positions[record.number]!.dx, top: layout.positions[record.number]!.dy,
            child: SizedBox(width: 260, height: 130, child: Card(margin: EdgeInsets.zero,
              child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [
                SizedBox(height: 20, child: Align(alignment: Alignment.centerLeft,
                  child: Tooltip(message: knockoutMatchName(record.match, records.where((r) => r.bracket == record.bracket).map((r) => r.match)), child: Text('Spiel ${record.number} · ${record.match.label ?? record.bracket}', maxLines: 1, overflow: TextOverflow.ellipsis)))),
                const SizedBox(height: 6),
                for (final home in [true, false])
                  SizedBox(height: 42, child: Tooltip(message: home ? record.homeSource : record.awaySource,
                    child: Row(key: ValueKey('graph-player-${record.number}-$home'), children: [
                      Expanded(child: Text(layout.playerLabel(record, home),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: layout.isWinner(record, home) ? FontWeight.bold : FontWeight.normal,
                          color: layout.isWinner(record, home) ? Colors.green.shade800 : null))),
                      Text('${(home ? record.match.homeScore : record.match.awayScore) ?? '-'}${record.match.hasSetScore ? ' S' : ''}'),
                      if (layout.isWinner(record, home)) const Icon(Icons.check, size: 16, color: Colors.green),
                    ]))),
              ]))))),
      ])),
    )));
  }
}

class SimulationGraphEdge {
  const SimulationGraphEdge(this.start, this.end, this.loser, this.lane);
  final Offset start;
  final Offset end;
  final bool loser;
  final double? lane;
  Path get path {
    if (lane == null) {
      final middle = (start.dx + end.dx) / 2;
      return Path()..moveTo(start.dx, start.dy)..cubicTo(middle, start.dy, middle, end.dy, end.dx, end.dy);
    }
    // Travel down the source gutter, below all cards, then up the target gutter.
    const radius = 8.0;
    final left = start.dx + 15;
    final right = end.dx - 15;
    return Path()..moveTo(start.dx, start.dy)
      ..lineTo(left - radius, start.dy)..quadraticBezierTo(left, start.dy, left, start.dy + radius)
      ..lineTo(left, lane! - radius)..quadraticBezierTo(left, lane!, left + radius, lane!)
      ..lineTo(right - radius, lane!)..quadraticBezierTo(right, lane!, right, lane! - radius)
      ..lineTo(right, end.dy + radius)..quadraticBezierTo(right, end.dy, right + radius, end.dy)
      ..lineTo(end.dx, end.dy);
  }
}

/// Card rows and connector anchors use the same fixed geometry.
class SimulationGraphLayout {
  SimulationGraphLayout(List<SimulationMatchRecord> records) {
    final byNumber = {for (final r in records) r.number: r};
    final columnOf = <int, int>{};
    final ordered = [...records]..sort((a, b) => a.number.compareTo(b.number));
    final losses = <String, int>{};
    for (final r in ordered) {
      for (final player in [r.match.homePlayer, r.match.awayPlayer]) {
        if (player != null) lossesBefore['${r.number}:${player.name}'] = losses[player.name] ?? 0;
      }
      final loser = r.match.loser;
      if (loser != null && r.match.hasResult) losses[loser.name] = (losses[loser.name] ?? 0) + 1;
      var column = 0;
      for (final text in [r.homeSource, r.awaySource]) {
        final source = _source(text);
        if (source != null && columnOf.containsKey(source.number)) {
          column = math.max(column, columnOf[source.number]! + 1);
        }
      }
      columnOf[r.number] = column;
      columns = math.max(columns, column + 1);
    }
    final lossLevels = records.map((r) => int.tryParse((r.match.label ?? '').split(' ').first) ?? 0).fold<int>(2, math.max);
    final finalSection = lossLevels + 1;
    int sectionOf(SimulationMatchRecord r) {
      final label = r.match.label ?? '';
      if (label.contains('Grand Final') || label.contains('Reset') || label.contains('Triple-KO Finalrunde')) return finalSection;
      final losses = int.tryParse(label.split(' ').first);
      if (losses != null && label.contains('Niederlage')) return losses;
      if (label.startsWith('1 Niederlage') || label.startsWith('Losers')) return 1;
      return 0;
    }
    final titles = ['Winner-Bracket · 0 Niederlagen', 'Loser-Bracket · 1 Niederlage', for (var n = 2; n <= lossLevels; n++) 'Loser-Bracket $n · $n Niederlagen', 'Finalspiele'];
    final finals = ordered.where((r) => sectionOf(r) == finalSection).toList();
    final others = ordered.where((r) => sectionOf(r) != finalSection).toList();
    if (finals.isNotEmpty && others.isNotEmpty) {
      final first = others.map((r) => columnOf[r.number]!).reduce(math.max) + 1;
      for (var i = 0; i < finals.length; i++) {
        columnOf[finals[i].number] = first + i;
      }
    }
    columns = columnOf.isEmpty ? 0 : columnOf.values.reduce(math.max) + 1;
    var cardArea = 0.0;
    for (final bracket in records.map((r) => r.bracket).toSet()) {
      final bracketTop = cardArea;
      for (var section = 0; section <= finalSection; section++) {
        final entries = ordered.where((r) => r.bracket == bracket && sectionOf(r) == section).toList();
        if (entries.isEmpty) continue;
        final cols = entries.map((r) => columnOf[r.number]!).toSet().toList()..sort();
        final top = section == finalSection ? bracketTop : cardArea;
        final maxRows = cols.map((c) => entries.where((r) => columnOf[r.number] == c).length).reduce(math.max);
        final bandHeight = math.max(250.0, maxRows * 170.0 + 90);
        headings.add((position: Offset(cols.first * 310 + 16, top), text: '$bracket · ${titles[section]}', section: true));
        for (var i = 0; i < cols.length; i++) {
          final c = cols[i];
          headings.add((position: Offset(c * 310 + 16, top + 36), text: section == finalSection ? 'Finale' : knockoutRoundName(i, cols.length), section: false));
          final matches = entries.where((r) => columnOf[r.number] == c).toList();
          for (var row = 0; row < matches.length; row++) {
            positions[matches[row].number] = Offset(c * 310 + 16, top + 70 + (bandHeight - 90) / matches.length * (row + .5) - 65);
          }
        }
        cardArea = math.max(cardArea, top + bandHeight + 36);
      }
    }
    var laneCount = 0;
    for (final r in records) {
      for (final home in [true, false]) {
        final source = _source(home ? r.homeSource : r.awaySource);
        final origin = source == null ? null : byNumber[source.number];
        if (source == null || origin == null) continue;
        final player = home ? r.match.homePlayer : r.match.awayPlayer;
        if (player == null) continue;
        final sourcePlayer = source.loser ? origin.match.loser : origin.match.winner;
        if (sourcePlayer?.name != player.name) continue;
        final sourceHome = origin.match.homePlayer?.name == player.name;
        final start = positions[origin.number]! + Offset(260, sourceHome ? 57 : 99);
        final end = positions[r.number]! + Offset(0, home ? 57 : 99);
        final skipsColumn = columnOf[r.number]! - columnOf[origin.number]! > 1;
        edges.add(SimulationGraphEdge(start, end, source.loser, skipsColumn ? cardArea + 16 * laneCount++ : null));
      }
    }
    width = columns * 310.0 + 16;
    height = cardArea + laneCount * 16 + 16;
  }
  int columns = 0;
  double width = 0, height = 0;
  final positions = <int, Offset>{};
  final headings = <({Offset position, String text, bool section})>[];
  final edges = <SimulationGraphEdge>[];
  final lossesBefore = <String, int>{};
  String playerLabel(SimulationMatchRecord record, bool home) {
    final player = home ? record.match.homePlayer : record.match.awayPlayer;
    if (player == null) return 'Freilos';
    return '${player.name} · ${lossesBefore['${record.number}:${player.name}'] ?? 0} N.';
  }
  bool isWinner(SimulationMatchRecord record, bool home) {
    final player = home ? record.match.homePlayer : record.match.awayPlayer;
    return player != null && record.match.winner?.name == player.name;
  }
  ({int number, bool loser})? _source(String text) {
    final match = RegExp(r'^(Sieger|Verlierer) Spiel (\d+)$').firstMatch(text);
    return match == null ? null : (number: int.parse(match.group(2)!), loser: match.group(1) == 'Verlierer');
  }
}

class SimulationConnections extends CustomPainter {
  const SimulationConnections(this.layout);
  final SimulationGraphLayout layout;
  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in layout.edges) {
      canvas.drawPath(edge.path, Paint()..color = edge.loser ? Colors.orange : Colors.green
        ..strokeWidth = 2..style = PaintingStyle.stroke);
    }
  }
  @override
  bool shouldRepaint(covariant SimulationConnections oldDelegate) => oldDelegate.layout != layout;
}
