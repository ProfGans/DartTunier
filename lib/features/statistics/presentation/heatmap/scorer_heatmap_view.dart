import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../scorer/domain/scorer_hit.dart';

class ScorerHeatmapView extends StatelessWidget {
  const ScorerHeatmapView({super.key, required this.hits});
  final List<ScorerHit> hits;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: AspectRatio(
        aspectRatio: 1,
        child: Semantics(
          label:
              'Dartboard-Heatmap mit ${hits.length} lokalisierten Treffern. Feldhäufigkeiten stehen unter der Grafik.',
          child: CustomPaint(
            painter: _Board(
              hits,
              Theme.of(context).textTheme.bodyMedium?.fontFamily,
            ),
          ),
        ),
      ),
    ),
  );
}

class _Board extends CustomPainter {
  _Board(this.hits, this.fontFamily);
  final List<ScorerHit> hits;
  final String? fontFamily;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff152923),
    );
    final center = Offset(size.width / 2, size.height / 2),
        scale = size.width / 500;
    const numbers = [
      20,
      1,
      18,
      4,
      13,
      6,
      10,
      15,
      2,
      17,
      3,
      19,
      7,
      16,
      8,
      11,
      14,
      9,
      12,
      5,
    ];
    for (var i = 0; i < 20; i++) {
      final angle = -math.pi / 2 - math.pi / 20 + i * math.pi / 10;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 170 * scale),
        angle,
        math.pi / 10,
        true,
        Paint()
          ..color = i.isEven
              ? const Color(0xff303b38)
              : const Color(0xffb4b9ad),
      );
      for (final ring in [(166.0, 8.0), (103.0, 8.0)]) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: ring.$1 * scale),
          angle,
          math.pi / 10,
          false,
          Paint()
            ..color = i.isEven
                ? const Color(0xff9c403e)
                : const Color(0xff346a52)
            ..style = PaintingStyle.stroke
            ..strokeWidth = ring.$2 * scale,
        );
      }
      final a = angle + math.pi / 20;
      final text = TextPainter(
        text: TextSpan(
          text: '${numbers[i]}',
          style: TextStyle(
            color: Colors.white,
            fontFamily: fontFamily,
            fontSize: 14 * size.width / 400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        center +
            Offset(math.cos(a), math.sin(a)) * 191 * scale -
            Offset(text.width / 2, text.height / 2),
      );
    }
    canvas.drawCircle(
      center,
      15.9 * scale,
      Paint()..color = const Color(0xff346a52),
    );
    canvas.drawCircle(
      center,
      6.35 * scale,
      Paint()..color = const Color(0xff9c403e),
    );
    final bins = <(int, int), int>{};
    for (final h in hits) {
      final key = ((h.location.x / 10).floor(), (h.location.y / 10).floor());
      bins.update(key, (v) => v + 1, ifAbsent: () => 1);
    }
    final maximum = bins.values.fold<int>(1, math.max);
    for (final e in bins.entries) {
      final amount = e.value / maximum;
      final color = amount < .5
          ? Color.lerp(Colors.blue, Colors.yellow, amount * 2)!
          : Color.lerp(Colors.yellow, Colors.red, (amount - .5) * 2)!;
      final point =
          center + Offset((e.key.$1 + .5) * 10, (e.key.$2 + .5) * 10) * scale;
      canvas.drawCircle(
        point,
        13 * scale,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: .9), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: point, radius: 13 * scale)),
      );
    }
    for (final h in hits) {
      if (!h.location.estimated && !h.location.corrected) continue;
      canvas.drawCircle(
        center + Offset(h.location.x, h.location.y) * scale,
        4 * scale,
        Paint()
          ..color = h.location.corrected ? Colors.cyanAccent : Colors.amber
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Board oldDelegate) => true;
}
