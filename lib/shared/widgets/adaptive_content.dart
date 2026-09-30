import 'package:flutter/material.dart';

/// Scrollable form/list content with readable desktop width and mobile insets.
/// Keep spatial canvases (brackets, boards, graphs) outside this constraint.
class AdaptiveContentList extends StatelessWidget {
  const AdaptiveContentList({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(24),
    this.maxWidth = 1120,
    this.primary,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double maxWidth;
  final bool? primary;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final insets = padding.resolve(Directionality.of(context));
            return ListView(
              primary: primary,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: constraints.maxWidth < 600
                  ? EdgeInsets.fromLTRB(
                      insets.left.clamp(0, 16).toDouble(),
                      insets.top,
                      insets.right.clamp(0, 16).toDouble(),
                      insets.bottom,
                    )
                  : insets,
              children: children,
            );
          },
        ),
      ),
    ),
  );
}

/// Natural-height tiles: text scaling never has to fit a fixed grid height.
class AdaptiveTileLayout extends StatelessWidget {
  const AdaptiveTileLayout({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final columns = (constraints.maxWidth / (340 * scale))
          .floor().clamp(1, 3);
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    },
  );
}
