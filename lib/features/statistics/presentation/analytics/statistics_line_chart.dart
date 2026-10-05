import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Charts have a textual/table equivalent on their detail page.
class StatisticsLineChart extends StatelessWidget {
  const StatisticsLineChart({
    super.key,
    required this.values,
    required this.description,
    this.onSelected,
    this.selected,
  });
  final List<double> values;
  final String description;
  final ValueChanged<int>? onSelected;
  final int? selected;
  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const Text('Noch keine Messwerte für einen Verlauf.');
    }
    final low = values.reduce(math.min), high = values.reduce(math.max);
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label:
          '$description. ${values.length} Messwerte, Minimum ${low.toStringAsFixed(2)}, Maximum ${high.toStringAsFixed(2)}. Einzelwerte stehen unter der Grafik.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Maximum ${high.toStringAsFixed(2)}'),
          LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              onTapUp: onSelected == null
                  ? null
                  : (details) {
                      final x =
                          ((details.localPosition.dx - 12) /
                                  (constraints.maxWidth - 24))
                              .clamp(0.0, 1.0);
                      onSelected!((x * (values.length - 1)).round());
                    },
              child: SizedBox(
                height: 180,
                child: CustomPaint(
                  painter: _LinePainter(
                    values,
                    color,
                    Theme.of(context).colorScheme.outlineVariant,
                    selected,
                  ),
                ),
              ),
            ),
          ),
          Text(
            'Minimum ${low.toStringAsFixed(2)} · Chronologisch von links nach rechts',
          ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values, this.color, this.grid, this.selected);
  final List<double> values;
  final Color color, grid;
  final int? selected;
  @override
  void paint(Canvas canvas, Size size) {
    final low = values.reduce(math.min),
        high = values.reduce(math.max),
        range = high - low;
    final paint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = 12 + (size.height - 24) * i / 3;
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), paint);
    }
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(
          values.length == 1
              ? size.width / 2
              : 12 + (size.width - 24) * i / (values.length - 1),
          range == 0
              ? size.height / 2
              : size.height -
                    12 -
                    (size.height - 24) * (values[i] - low) / range,
        ),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(
        points[i],
        i == selected ? 6 : 3,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => true;
}
