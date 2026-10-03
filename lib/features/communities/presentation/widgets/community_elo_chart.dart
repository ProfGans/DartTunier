import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/community_elo.dart';

/// Matches form the horizontal axis; timestamps in legacy results may be absent.
class CommunityEloChart extends StatefulWidget {
  const CommunityEloChart({super.key, required this.history});
  final List<CommunityEloHistoryItem> history;
  @override
  State<CommunityEloChart> createState() => _CommunityEloChartState();
}

class _CommunityEloChartState extends State<CommunityEloChart> {
  int? selected;
  @override
  Widget build(BuildContext context) {
    final ratings = [
      communityInitialElo,
      ...widget.history.map((e) => e.ratingAfter),
    ];
    final index = (selected ?? ratings.length - 1).clamp(0, ratings.length - 1);
    final minimum = ratings.reduce(math.min);
    final maximum = ratings.reduce(math.max);
    final item = index == 0 ? null : widget.history[index - 1];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Elo-Verlauf', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Wertebereich: $minimum–$maximum Elo'),
            const SizedBox(height: 12),
            Semantics(
              label:
                  'Elo-Verlauf: Start 1000, aktuell ${ratings.last}, niedrigster Wert $minimum, höchster Wert $maximum.',
              child: SizedBox(
                height: 180,
                child: CustomPaint(
                  painter: _EloPainter(
                    ratings,
                    index,
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Von links nach rechts: Start → gespielte Begegnungen'),
            if (widget.history.isNotEmpty)
              Slider(
                label: 'Begegnung $index: ${ratings[index]} Elo',
                semanticFormatterCallback: (value) =>
                    'Begegnung ${value.round()}: ${ratings[value.round()]} Elo',
                value: index.toDouble(),
                min: 0,
                max: widget.history.length.toDouble(),
                divisions: widget.history.length,
                onChanged: (value) => setState(() => selected = value.round()),
              ),
            Text(
              item == null
                  ? 'Startwert: $communityInitialElo Elo'
                  : 'Begegnung $index · ${item.opponentName} · ${item.score}\n${item.ratingAfter} Elo (${item.delta >= 0 ? '+' : ''}${item.delta})',
            ),
          ],
        ),
      ),
    );
  }
}

class _EloPainter extends CustomPainter {
  _EloPainter(this.values, this.selected, this.color, this.grid);
  final List<int> values;
  final int selected;
  final Color color, grid;
  @override
  void paint(Canvas canvas, Size size) {
    final low = values.reduce(math.min) - 10;
    final high = values.reduce(math.max) + 10;
    final paint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = 8 + (size.height - 16) * i / 4;
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), paint);
    }
    Offset point(int i) => Offset(
      8 + (size.width - 16) * i / math.max(1, values.length - 1),
      size.height - 8 - (size.height - 16) * (values[i] - low) / (high - low),
    );
    final path = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(point(i).dx, point(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(point(selected), 6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _EloPainter old) =>
      old.values != values ||
      old.selected != selected ||
      old.color != color ||
      old.grid != grid;
}
