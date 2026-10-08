import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'scorer_play_sizing.dart';

/// Three-column touch entry on phones, calculator layout on wider surfaces.
class ScoreKeypad extends StatefulWidget {
  const ScoreKeypad({
    super.key,
    required this.enabled,
    required this.remaining,
    required this.onSubmit,
    required this.onBust,
    this.onUndo,
  });
  final bool enabled;
  final int remaining;
  final Future<bool> Function(int) onSubmit;
  final VoidCallback onBust;
  final VoidCallback? onUndo;
  @override
  State<ScoreKeypad> createState() => _ScoreKeypadState();
}

class _ScoreKeypadState extends State<ScoreKeypad> {
  String input = '';
  bool submitting = false;
  bool get enabled => widget.enabled && !submitting;
  final focus = FocusNode();
  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ScoreKeypad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) input = '';
  }

  void digit(String value) {
    if (!enabled) return;
    setState(() {
      if (input == '0') input = '';
      if (input.length < 3) input += value;
    });
  }

  Future<void> submit([int? value]) async {
    if (!enabled || (value == null && input.isEmpty)) return;
    setState(() => submitting = true);
    try {
      final accepted = await widget.onSubmit(value ?? int.parse(input));
      if (mounted && accepted) setState(() => input = '');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Widget button(
    String label,
    VoidCallback? callback, {
    bool primary = false,
  }) => Expanded(
    child: Padding(
      padding: const EdgeInsets.all(3),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: ScorerPlaySizing.of(context)?.keyHeight ?? 64,
        ),
        child: primary
            ? FilledButton(
                onPressed: callback,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: label == '⌫'
                    ? const Tooltip(
                        message: 'Letzte Ziffer löschen',
                        child: Icon(Icons.backspace_outlined),
                      )
                    : Text(
                        label,
                        style: TextStyle(
                          fontSize:
                              ((ScorerPlaySizing.of(context)?.keyHeight ?? 64) /
                                      4)
                                  .clamp(24.0, 40.0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              )
            : OutlinedButton(
                onPressed: callback,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: label == '⌫'
                    ? const Tooltip(
                        message: 'Letzte Ziffer löschen',
                        child: Icon(Icons.backspace_outlined),
                      )
                    : Text(
                        label,
                        style: TextStyle(
                          fontSize:
                              ((ScorerPlaySizing.of(context)?.keyHeight ?? 64) /
                                      4)
                                  .clamp(24.0, 40.0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    focusNode: focus,
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent || !enabled) return KeyEventResult.ignored;
      final char = event.character;
      if (char != null && RegExp(r'^\d$').hasMatch(char)) {
        digit(char);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        submit();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        setState(() {
          if (input.isNotEmpty) input = input.substring(0, input.length - 1);
        });
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => input = '');
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 420 ||
                MediaQuery.textScalerOf(context).scale(16) > 24;
            return Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Rückgängig',
                      onPressed: submitting || widget.onUndo == null
                          ? null
                          : () {
                              setState(() => input = '');
                              widget.onUndo!();
                            },
                      icon: const Icon(Icons.undo),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('AUFNAHME · 0–180'),
                            Text(
                              input.isEmpty ? '—' : input,
                              key: const ValueKey('score-display'),
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: enabled && widget.remaining <= 180
                          ? () => submit(widget.remaining)
                          : null,
                      child: Text('CHECK\n${widget.remaining}'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (compact) ...[
                  for (var row = 0; row < 3; row++)
                    Row(
                      children: [
                        for (var col = 1; col <= 3; col++)
                          button(
                            '${row * 3 + col}',
                            enabled ? () => digit('${row * 3 + col}') : null,
                          ),
                      ],
                    ),
                  Row(
                    children: [
                      button(
                        'C',
                        enabled ? () => setState(() => input = '') : null,
                      ),
                      button('0', enabled ? () => digit('0') : null),
                      button(
                        '⌫',
                        enabled
                            ? () => setState(() {
                                if (input.isNotEmpty) {
                                  input = input.substring(0, input.length - 1);
                                }
                              })
                            : null,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      button(
                        input.isEmpty ? '180' : 'OK',
                        enabled
                            ? () => input.isEmpty ? submit(180) : submit()
                            : null,
                        primary: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final points in [26, 41, 60, 81, 100, 140])
                        OutlinedButton(
                          onPressed: enabled ? () => submit(points) : null,
                          child: Text('$points'),
                        ),
                    ],
                  ),
                ] else ...[
                  for (var row = 0; row < 3; row++)
                    Row(
                      children: [
                        button(
                          '${[26, 41, 60][row]}',
                          enabled ? () => submit([26, 41, 60][row]) : null,
                        ),
                        for (var col = 1; col <= 3; col++)
                          button(
                            '${row * 3 + col}',
                            enabled ? () => digit('${row * 3 + col}') : null,
                          ),
                        button(
                          '${[81, 100, 140][row]}',
                          enabled ? () => submit([81, 100, 140][row]) : null,
                        ),
                      ],
                    ),
                  Row(
                    children: [
                      button(
                        'C',
                        enabled ? () => setState(() => input = '') : null,
                      ),
                      button(
                        '⌫',
                        enabled
                            ? () => setState(() {
                                if (input.isNotEmpty) {
                                  input = input.substring(0, input.length - 1);
                                }
                              })
                            : null,
                      ),
                      button('0', enabled ? () => digit('0') : null),
                      button(
                        input.isEmpty ? '180' : 'OK',
                        enabled
                            ? () {
                                if (input.isEmpty) {
                                  submit(180);
                                } else {
                                  submit();
                                }
                              }
                            : null,
                        primary: true,
                      ),
                    ],
                  ),
                ],
                TextButton(
                  onPressed: enabled
                      ? () {
                          setState(() => input = '');
                          widget.onBust();
                        }
                      : null,
                  child: const Text('Überworfen'),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
