import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/board_geometry.dart';
import '../../domain/flat_board_projection.dart';
import 'flat_board_view.dart';

class DartPositionDialog extends StatefulWidget {
  const DartPositionDialog({
    super.key,
    required this.cameras,
    this.initialPoint,
  });
  final List<FlatBoardCamera> cameras;
  final BoardPoint? initialPoint;
  @override
  State<DartPositionDialog> createState() => _DartPositionDialogState();
}

class _DartPositionDialogState extends State<DartPositionDialog> {
  late BoardPoint? point = widget.initialPoint;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(12),
    child: LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: min(600, constraints.maxWidth),
        height: min(850, constraints.maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Einschlagpunkt setzen',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Auf den tatsächlichen Einschlagpunkt tippen. Danach kannst du den Punkt ziehen oder mit den Pfeilbuttons fein verschieben. Die Position und der daraus berechnete Score werden als Korrektur gespeichert.',
                      ),
                      FlatBoardView(
                        cameras: widget.cameras,
                        markers: [
                          if (point != null)
                            FlatBoardMarker(
                              0,
                              point!,
                              BoardGeometry.score(point!).label,
                            ),
                        ],
                        onPlaced: (value) => setState(() => point = value),
                        onMoved: (_, value) => setState(() => point = value),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            setState(() => point = const BoardPoint(0, 0)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        child: const Text('Punkt in der Mitte setzen'),
                      ),
                      if (point != null)
                        Text(
                          '${BoardGeometry.score(point!).label} · ${BoardGeometry.score(point!).scoredPoints} Punkte · x ${point!.x.toStringAsFixed(1)} mm / y ${point!.y.toStringAsFixed(1)} mm',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Abbrechen'),
                  ),
                  FilledButton(
                    onPressed: point == null
                        ? null
                        : () => Navigator.pop(context, point),
                    child: const Text('Position speichern'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
