import 'package:flutter/material.dart';

/// Shares the available playing-surface height with score panels and touch input.
class ScorerPlaySizing extends InheritedWidget {
  const ScorerPlaySizing({
    super.key,
    required super.child,
    this.scoreHeight = 0,
    this.keyHeight = 64,
  });
  final double scoreHeight, keyHeight;
  static ScorerPlaySizing? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScorerPlaySizing>();
  @override
  bool updateShouldNotify(ScorerPlaySizing oldWidget) =>
      scoreHeight != oldWidget.scoreHeight || keyHeight != oldWidget.keyHeight;
}
