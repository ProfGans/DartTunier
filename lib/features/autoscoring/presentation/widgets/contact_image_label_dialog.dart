import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../../data/autoscore_diagnostic_export.dart';
import '../../domain/contact_training_label.dart';

class ContactImageLabelDialog extends StatefulWidget {
  const ContactImageLabelDialog({super.key, required this.evidence});
  final AutoscoreEvidence evidence;
  @override
  State<ContactImageLabelDialog> createState() =>
      _ContactImageLabelDialogState();
}

class _ContactImageLabelDialogState extends State<ContactImageLabelDialog> {
  int camera = 0, marker = 0;
  final imageFocus = FocusNode();
  Map? _savedLabel(int i) =>
      (widget.evidence.hit['cameraTrainingLabels'] as List? ?? [])
          .whereType<Map>()
          .where(
            (m) =>
                m['camera'] ==
                (widget.evidence.cameras[i].metadata['camera'] ?? i + 1),
          )
          .firstOrNull;
  Map<String, double>? _point(Object? raw) =>
      raw is Map && raw['x'] is num && raw['y'] is num
      ? {'x': (raw['x'] as num).toDouble(), 'y': (raw['y'] as num).toDouble()}
      : null;
  late final points = List.generate(widget.evidence.cameras.length, (i) {
    final label = _savedLabel(i);
    final shaft = label?['shaftEndpoints'] as List? ?? [];
    return [
      _point(label?['verifiedImagePoint']),
      shaft.isNotEmpty ? _point(shaft[0]) : null,
      shaft.length > 1 ? _point(shaft[1]) : null,
    ];
  });
  late final visibility = List<bool?>.generate(
    points.length,
    (i) => _savedLabel(i)?['occluded'] as bool?,
  );
  late final aspects = [
    for (final c in widget.evidence.cameras)
      (() {
        final image = img.decodeImage(c.image);
        return image == null ? 16 / 9 : image.width / image.height;
      })(),
  ];
  KeyEventResult _move(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final direction = {
      LogicalKeyboardKey.arrowLeft: (-1.0, 0.0),
      LogicalKeyboardKey.arrowRight: (1.0, 0.0),
      LogicalKeyboardKey.arrowUp: (0.0, -1.0),
      LogicalKeyboardKey.arrowDown: (0.0, 1.0),
    }[event.logicalKey];
    if (direction == null) return KeyEventResult.ignored;
    final old = points[camera][marker] ?? {'x': .5, 'y': .5};
    setState(
      () => points[camera][marker] = {
        'x': (old['x']! + direction.$1 / 1280).clamp(0, 1),
        'y': (old['y']! + direction.$2 / 720).clamp(0, 1),
      },
    );
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    imageFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final imageWidth = (bounds.maxWidth - 64).clamp(1.0, 800.0);
      return AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        contentPadding: const EdgeInsets.all(16),
        title: const Text('Originalbilder für Modelltraining prüfen'),
        scrollable: true,
        content: SizedBox(
          width: imageWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nur den zuletzt geworfenen Dart markieren. Spitze und zwei Punkte auf seinem Schaft direkt im Bild setzen. Bei verdeckter Spitze „Verdeckt“ wählen. Unklare Bilder bleiben ungeprüft.',
              ),
              DropdownButtonFormField<int>(
                isExpanded: true,
                itemHeight: null,
                initialValue: camera,
                items: [
                  for (var i = 0; i < points.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        'Kamera ${widget.evidence.cameras[i].metadata['camera'] ?? i + 1}',
                      ),
                    ),
                ],
                onChanged: (i) => setState(() => camera = i!),
                decoration: const InputDecoration(labelText: 'Kamera'),
              ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                itemHeight: null,
                key: ValueKey('visibility_$camera'),
                initialValue: visibility[camera] == null
                    ? 'Unbekannt'
                    : visibility[camera]!
                    ? 'Verdeckt'
                    : 'Sichtbar',
                items: [
                  for (final v in ['Unbekannt', 'Sichtbar', 'Verdeckt'])
                    DropdownMenuItem(value: v, child: Text(v)),
                ],
                onChanged: (v) => setState(
                  () => visibility[camera] = v == 'Unbekannt'
                      ? null
                      : v == 'Verdeckt',
                ),
                decoration: const InputDecoration(
                  labelText: 'Sichtbarkeit der Spitze',
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < 3; i++)
                    ChoiceChip(
                      label: Text(
                        ['Spitze', 'Schaftpunkt 1', 'Schaftpunkt 2'][i],
                      ),
                      selected: marker == i,
                      onSelected: (_) => setState(() => marker = i),
                    ),
                ],
              ),
              Container(
                width: imageWidth,
                height: imageWidth / aspects[camera],
                foregroundDecoration: BoxDecoration(
                  border: Border.all(
                    width: 2,
                    color: imageFocus.hasFocus
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                  ),
                ),
                child: InteractiveViewer(
                  maxScale: 6,
                  child: Focus(
                    focusNode: imageFocus,
                    onFocusChange: (_) => setState(() {}),
                    onKeyEvent: _move,
                    child: GestureDetector(
                      key: const ValueKey('contact-image-gesture'),
                      onTapDown: (details) => setState(() {
                        imageFocus.requestFocus();
                        points[camera][marker] = {
                          'x': (details.localPosition.dx / imageWidth).clamp(
                            0,
                            1,
                          ),
                          'y':
                              (details.localPosition.dy /
                                      (imageWidth / aspects[camera]))
                                  .clamp(0, 1),
                        };
                      }),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(
                            widget.evidence.cameras[camera].image,
                            fit: BoxFit.fill,
                          ),
                          for (var i = 0; i < 3; i++)
                            if (points[camera][i] != null)
                              Positioned(
                                left: points[camera][i]!['x']! * imageWidth - 8,
                                top:
                                    points[camera][i]!['y']! *
                                        (imageWidth / aspects[camera]) -
                                    8,
                                child: IgnorePointer(
                                  child: Icon(
                                    Icons.add_circle,
                                    size: 16,
                                    color: [
                                      Colors.pinkAccent,
                                      Colors.cyanAccent,
                                      Colors.yellowAccent,
                                    ][i],
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Zum genauen Markieren zoomen. Nach einem Klick verschieben die Pfeiltasten den gewählten Punkt.',
              ),
              OutlinedButton(
                onPressed: () =>
                    setState(() => points[camera].fillRange(0, 3, null)),
                child: const Text('Markierungen dieser Kamera löschen'),
              ),
              const Text(
                'Bildlabels dienen der Trainingsvorbereitung. Sie verändern keinen Treffer und aktivieren noch kein Modell.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, [
              for (var i = 0; i < points.length; i++)
                contactTrainingLabel(
                  camera:
                      widget.evidence.cameras[i].metadata['camera'] as int? ??
                      i + 1,
                  occluded: visibility[i],
                  reviewed: visibility[i] != null,
                  tip: points[i][0],
                  shaft: [for (final p in points[i].skip(1)) ?p],
                ),
            ]),
            child: const Text('Bildlabels speichern'),
          ),
        ],
      );
    },
  );
}
