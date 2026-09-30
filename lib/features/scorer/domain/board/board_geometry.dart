import 'dart:math';

import '../x01/x01_models.dart';
import '../x01/x01_rules.dart';

class BoardPoint {
  const BoardPoint(this.x, this.y);

  final double x;
  final double y;
}

class BoardRadii {
  const BoardRadii({
    this.bull = 12,
    this.outerBull = 28,
    this.singleInner = 105,
    this.tripleOuter = 123,
    this.singleOuter = 188,
    this.doubleOuter = 206,
    this.boardOuter = 240,
  });

  final double bull;
  final double outerBull;
  final double boardOuter;
  final double doubleOuter;
  final double singleOuter;
  final double tripleOuter;
  final double singleInner;
}

class BoardGeometry {
  const BoardGeometry({
    this.radii = const BoardRadii(),
    this.center = const BoardPoint(250, 250),
  });

  final BoardRadii radii;
  final BoardPoint center;

  BoardPoint aimPointForThrow(DartThrowResult dartThrow) {
    if (dartThrow.isBull) {
      return center;
    }

    if (dartThrow.label == '25') {
      return _segmentMarkerPoint((radii.bull + radii.outerBull) / 2, 0);
    }

    final segmentIndex = X01Rules.wheel.indexOf(dartThrow.baseValue);
    final centerAngle = segmentIndex * 18.0;

    if (dartThrow.isDouble) {
      return _segmentMarkerPoint(
        (radii.singleOuter + radii.doubleOuter) / 2,
        centerAngle,
      );
    }

    if (dartThrow.isTriple) {
      return _segmentMarkerPoint(
        (radii.singleInner + radii.tripleOuter) / 2,
        centerAngle,
      );
    }

    final singleRadius = dartThrow.baseValue <= 10
        ? (radii.outerBull + radii.singleInner) / 2
        : (radii.tripleOuter + radii.singleOuter) / 2;
    return _segmentMarkerPoint(singleRadius, centerAngle);
  }

  DartThrowResult classifyBoardPoint(
    double x,
    double y, {
    required X01Rules rules,
  }) {
    final dx = x - center.x;
    final dy = y - center.y;
    final radius = sqrt(dx * dx + dy * dy);

    if (radius > radii.boardOuter) {
      return rules.createMiss();
    }

    if (radius <= radii.bull) {
      return rules.createBull();
    }

    if (radius <= radii.outerBull) {
      return rules.createOuterBull();
    }

    final angle = _normalizeAngle((atan2(dy, dx) * 180 / pi) + 90);
    final segmentIndex = (((angle + 9) ~/ 18) % X01Rules.wheel.length);
    final value = X01Rules.wheel[segmentIndex];

    if (radius <= radii.singleInner) {
      return rules.createSingle(value);
    }

    if (radius <= radii.tripleOuter) {
      return rules.createTriple(value);
    }

    if (radius <= radii.singleOuter) {
      return rules.createSingle(value);
    }

    if (radius <= radii.doubleOuter) {
      return rules.createDouble(value);
    }

    return rules.createSingle(value);
  }

  double radialFactorForThrow(DartThrowResult dartThrow) {
    final aimPoint = aimPointForThrow(dartThrow);
    return radialFactorForPoint(aimPoint);
  }

  double radialFactorForPoint(BoardPoint point) {
    final dx = point.x - center.x;
    final dy = point.y - center.y;
    return sqrt(dx * dx + dy * dy) / radii.doubleOuter;
  }

  BoardPoint applyScatter(
    BoardPoint targetPoint,
    double scatterRadius,
    double angle,
    double distanceFactor,
  ) {
    if (scatterRadius <= 0) {
      return targetPoint;
    }

    final distance = scatterRadius * distanceFactor;
    return BoardPoint(
      targetPoint.x + cos(angle) * distance,
      targetPoint.y + sin(angle) * distance,
    );
  }

  BoardPoint _segmentMarkerPoint(double radius, double angleDegrees) {
    final radians = ((angleDegrees - 90) * pi) / 180;
    return BoardPoint(
      center.x + radius * cos(radians),
      center.y + radius * sin(radians),
    );
  }

  double _normalizeAngle(double angle) {
    return ((angle % 360) + 360) % 360;
  }
}
