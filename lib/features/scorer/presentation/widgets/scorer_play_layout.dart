import 'package:flutter/material.dart';
import 'scorer_play_sizing.dart';

/// Independent scrolling in landscape keeps scores and input within reach.
class ScorerPlayLayout extends StatefulWidget {
  const ScorerPlayLayout({
    super.key,
    required this.board,
    required this.input,
    required this.toolbar,
    required this.history,
    this.expandScores = false,
  });
  final bool expandScores;
  final Widget board, input, toolbar, history;
  @override
  State<ScorerPlayLayout> createState() => _ScorerPlayLayoutState();
}

class _ScorerPlayLayoutState extends State<ScorerPlayLayout> {
  final _boardKey = GlobalKey();
  final _inputKey = GlobalKey();
  final _toolbarKey = GlobalKey();
  final _historyKey = GlobalKey();
  Widget get board => KeyedSubtree(key: _boardKey, child: widget.board);
  Widget get input => KeyedSubtree(key: _inputKey, child: widget.input);
  Widget get toolbar => KeyedSubtree(key: _toolbarKey, child: widget.toolbar);
  Widget get history => KeyedSubtree(key: _historyKey, child: widget.history);
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final wide = bounds.maxWidth >= 700 && bounds.maxWidth >= 600 * scale;
      final padding = bounds.maxWidth < 600 ? 8.0 : 16.0;
      final spacious =
          wide &&
          bounds.maxWidth >= 1000 &&
          bounds.maxHeight >= 650 &&
          scale <= 1.5;
      final scores = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          toolbar,
          const SizedBox(height: 8),
          board,
          if (spacious) ...[
            const SizedBox(height: 20),
            history,
          ] else
            ExpansionTile(
              title: const Text('Schreibertafel · Leg-Verlauf'),
              children: [history],
            ),
        ],
      );
      if (widget.expandScores) {
        return ScorerPlaySizing(
          scoreHeight: spacious
              ? (bounds.maxHeight * .52).clamp(280.0, 720.0)
              : 0,
          keyHeight: 64,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                toolbar,
                input,
                const SizedBox(height: 8),
                board,
                const SizedBox(height: 16),
                if (spacious)
                  history
                else
                  ExpansionTile(
                    title: const Text('Schreibertafel · Leg-Verlauf'),
                    children: [history],
                  ),
              ],
            ),
          ),
        );
      }
      if (!wide) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            children: [
              toolbar,
              const SizedBox(height: 8),
              board,
              const SizedBox(height: 12),
              input,
              ExpansionTile(
                title: const Text('Schreibertafel · Leg-Verlauf'),
                children: [history],
              ),
            ],
          ),
        );
      }
      return ScorerPlaySizing(
        scoreHeight: spacious
            ? (bounds.maxHeight * .52).clamp(280.0, 720.0)
            : 0,
        keyHeight: spacious ? (bounds.maxHeight * .14).clamp(72.0, 180.0) : 64,
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  key: const PageStorageKey('scorer-scores'),
                  child: scores,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SingleChildScrollView(
                  key: const PageStorageKey('scorer-input'),
                  child: input,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
