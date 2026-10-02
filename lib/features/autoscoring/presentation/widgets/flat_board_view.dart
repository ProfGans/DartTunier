import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../domain/board_geometry.dart';
import '../../domain/flat_board_projection.dart';

class FlatBoardMarker {
  const FlatBoardMarker(this.index, this.point, this.label);
  final int index;
  final BoardPoint point;
  final String label;
}

class FlatBoardView extends StatefulWidget {
  const FlatBoardView({
    super.key,
    required this.cameras,
    required this.markers,
    required this.onMoved,
  });
  final List<FlatBoardCamera> cameras;
  final List<FlatBoardMarker> markers;
  final void Function(int, BoardPoint) onMoved;
  @override
  State<FlatBoardView> createState() => _FlatBoardViewState();
}

class _FlatBoardViewState extends State<FlatBoardView> {
  Uint8List? image;
  List<FlatBoardCamera>? rendered;
  bool busy = false;
  DateTime? lastRender;
  int? selected;
  Offset? drag;
  @override
  void initState() {
    super.initState();
    _render();
  }

  @override
  void didUpdateWidget(covariant FlatBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _render();
  }

  Future<void> _render() async {
    if (busy || widget.cameras.isEmpty) return;
    if (widget.markers.isEmpty &&
        lastRender != null &&
        DateTime.now().difference(lastRender!) < const Duration(seconds: 1)) {
      return;
    }
    final input = widget.cameras;
    if (rendered != null &&
        listEquals(
          rendered!.map((c) => c.image).toList(),
          input.map((c) => c.image).toList(),
        )) {
      return;
    }
    busy = true;
    lastRender = DateTime.now();
    try {
      final result = await compute(projectFlatBoard, input);
      if (mounted) {
        setState(() {
          image = result;
          rendered = input;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          image = null;
          rendered = input;
        });
      }
    } finally {
      busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = min(560.0, constraints.maxWidth);
      Offset position(BoardPoint p) =>
          Offset((p.x / 380 + .5) * size, (p.y / 380 + .5) * size);
      BoardPoint point(Offset p) {
        var q = Point((p.dx / size - .5) * 380, (p.dy / size - .5) * 380);
        if (q.magnitude > 190) q *= 190 / q.magnitude;
        return q;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Flache Boardansicht',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(
            'Treffer auswählen und den Punkt ziehen. Die Pfeilbuttons verschieben um 1 mm. Die Korrektur wird gespeichert.',
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final marker in widget.markers)
                ChoiceChip(
                  label: Text('${marker.index + 1}: ${marker.label}'),
                  selected: selected == marker.index,
                  onSelected: (_) => setState(() {
                    selected = marker.index;
                    drag = null;
                  }),
                ),
            ],
          ),
          Center(
            child: SizedBox(
              width: size,
              height: size,
              child: Padding(
                padding: EdgeInsets.zero,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: const Color(0xff232323),
                        child: image == null
                            ? const Center(
                                child: Text(
                                  'Nach der Kalibrierung erscheint die Kameraansicht.',
                                  style: TextStyle(color: Colors.white),
                                ),
                              )
                            : Image.memory(
                                image!,
                                fit: BoxFit.fill,
                                gaplessPlayback: true,
                              ),
                      ),
                    ),
                    for (final marker in widget.markers)
                      Positioned(
                        left:
                            (selected == marker.index && drag != null
                                    ? drag!
                                    : position(marker.point))
                                .dx -
                            24,
                        top:
                            (selected == marker.index && drag != null
                                    ? drag!
                                    : position(marker.point))
                                .dy -
                            24,
                        child: Semantics(
                          label: 'Treffer ${marker.index + 1}: ${marker.label}',
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: GestureDetector(
                              onPanStart: (details) => setState(() {
                                selected = marker.index;
                                drag =
                                    position(marker.point) +
                                    details.localPosition -
                                    const Offset(24, 24);
                              }),
                              onPanUpdate: (details) => setState(() {
                                drag =
                                    (drag ?? position(marker.point)) +
                                    details.delta;
                              }),
                              onPanCancel: () => setState(() {
                                drag = null;
                              }),
                              onPanEnd: (_) {
                                if (drag != null) {
                                  widget.onMoved(marker.index, point(drag!));
                                }
                                setState(() {
                                  drag = null;
                                });
                              },
                              child: IconButton(
                                tooltip:
                                    'Treffer ${marker.index + 1} auswählen',
                                onPressed: () => setState(() {
                                  selected = marker.index;
                                }),
                                icon: Icon(
                                  Icons.adjust,
                                  color: selected == marker.index
                                      ? Colors.yellow
                                      : Colors.pinkAccent,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (selected != null &&
              widget.markers.any((m) => m.index == selected))
            Wrap(
              spacing: 8,
              children: [
                for (final direction in const [
                  (Icons.arrow_back, -1.0, 0.0, 'Links'),
                  (Icons.arrow_forward, 1.0, 0.0, 'Rechts'),
                  (Icons.arrow_upward, 0.0, -1.0, 'Oben'),
                  (Icons.arrow_downward, 0.0, 1.0, 'Unten'),
                ])
                  IconButton(
                    tooltip: '${direction.$4} um 1 mm',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () {
                      final marker = widget.markers.firstWhere(
                        (m) => m.index == selected,
                      );
                      widget.onMoved(
                        marker.index,
                        marker.point + Point(direction.$2, direction.$3),
                      );
                    },
                    icon: Icon(direction.$1),
                  ),
              ],
            ),
          const Text(
            'Die drei Kameras werden auf die Boardebene entzerrt und zusammengeführt. Schäfte können durch ihre Höhe versetzt erscheinen.',
          ),
        ],
      );
    },
  );
}
