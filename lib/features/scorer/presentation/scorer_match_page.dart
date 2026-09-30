import 'dart:async';
import 'package:flutter/material.dart';
import '../application/scorer_controller.dart';
import '../domain/scorer_settings.dart';
import '../domain/visit_score_entry.dart';
import '../domain/x01/x01_models.dart';
import 'checkout_page.dart';
import 'widgets/score_keypad.dart';
import 'widgets/scorer_statistics_view.dart';
import 'widgets/checkout_attempt_dialog.dart';

class ScorerMatchPage extends StatefulWidget {
  const ScorerMatchPage({super.key, required this.settings});
  final ScorerSettings settings;
  @override
  State<ScorerMatchPage> createState() => _ScorerMatchPageState();
}

class _ScorerMatchPageState extends State<ScorerMatchPage> {
  late final ScorerController controller;
  Timer? timer;
  bool _bustPending = false;
  Future<void> _showStatistics() async {
    timer?.cancel();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .85,
          child: ScorerStatisticsView(
            statistics: controller.statistics,
            settings: widget.settings,
          ),
        ),
      ),
    );
    if (mounted) _scheduleBot();
  }

  Future<void> _submitBust() async {
    if (_bustPending || controller.isBotTurn || controller.winner != null) {
      return;
    }
    _bustPending = true;
    try {
      int? attempts;
      final maximum = controller.maxCheckoutAttempts();
      if (maximum > 0 &&
          widget.settings.checkoutRequirement ==
              CheckoutRequirement.doubleOut) {
        final answer = await askCheckoutAttempts(
          context,
          maximum: maximum,
          finish: false,
        );
        if (!mounted || answer == null) return;
        attempts = answer.$1;
      }
      controller.submitBust(checkoutAttempts: attempts);
    } finally {
      _bustPending = false;
    }
  }

  @override
  void initState() {
    super.initState();
    controller = ScorerController(widget.settings)..addListener(_changed);
    _scheduleBot();
  }

  void _changed() {
    setState(() {});
    _scheduleBot();
  }

  void _scheduleBot() {
    timer?.cancel();
    if (controller.isBotTurn) {
      timer = Timer(widget.settings.botThrowDelay, controller.playBotDart);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.removeListener(_changed);
    controller.dispose();
    super.dispose();
  }

  Future<bool> _submit(int points) async {
    final c = controller;
    if (c.isBotTurn || c.winner != null) return false;
    int? darts;
    if (points == c.remaining) {
      final needsOpening =
          widget.settings.startRequirement == StartRequirement.doubleIn &&
          !c.opened[c.activePlayer];
      final options = [
        for (var n = 1; n <= 3; n++)
          if (VisitScoreEntry.canFinish(
            points,
            n,
            widget.settings.checkoutRequirement,
            doubleIn: needsOpening,
          ))
            n,
      ];
      if (options.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Dieser Rest ist mit der In-/Out-Regel nicht in drei Darts auszuchecken.',
            ),
          ),
        );
        return false;
      }
      darts = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Checkout bestätigen'),
          content: Text(
            '$points Punkte · ${checkoutLabel(widget.settings.checkoutRequirement)}\nMit wie vielen Darts hast du ausgecheckt?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            for (final n in options)
              FilledButton(
                onPressed: () => Navigator.pop(context, n),
                child: Text('$n Dart${n == 1 ? '' : 's'}'),
              ),
          ],
        ),
      );
      if (!mounted || darts == null) return false;
    } else if (points > 0 &&
        widget.settings.startRequirement == StartRequirement.doubleIn &&
        !c.opened[c.activePlayer]) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Double In bestätigen'),
          content: const Text(
            'Hast du mit einem Doppel eröffnet? Gib nur die Punkte ab dem eröffnenden Doppel ein.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Mit Doppel eröffnet'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return false;
    }
    try {
      // Validate before requesting additional statistics.
      VisitScoreEntry.evaluate(
        score: c.remaining,
        points: points,
        start: widget.settings.startRequirement,
        out: widget.settings.checkoutRequirement,
        opened: c.opened[c.activePlayer],
        checkoutDarts: darts,
      );
      int? attempts;
      final maximum = c.maxCheckoutAttempts(darts: darts ?? 3);
      if (maximum > 0 &&
          !(darts != null && maximum == 1) &&
          widget.settings.checkoutRequirement ==
              CheckoutRequirement.doubleOut) {
        final answer = await askCheckoutAttempts(
          context,
          maximum: maximum,
          finish: darts != null,
        );
        if (!mounted || answer == null) return false;
        attempts = answer.$1;
      }
      c.submitScore(points, checkoutDarts: darts, checkoutAttempts: attempts);
      return true;
    } on ArgumentError catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${e.message}')));
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final statistics = c.statistics;
    final board = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${widget.settings.startScore} · ${checkoutLabel(widget.settings.checkoutRequirement)} · Best of ${widget.settings.bestOfLegs} Legs'
          '${widget.settings.bestOfSets > 1 ? ' · Best of ${widget.settings.bestOfSets} Sets' : ''}',
        ),
        for (var i = 0; i < widget.settings.participants.length; i++)
          Card(
            color: i == c.activePlayer
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: ListTile(
              leading: Icon(
                widget.settings.participants[i].bot == null
                    ? Icons.person_outline
                    : Icons.smart_toy_outlined,
              ),
              title: Text(widget.settings.participants[i].name),
              subtitle: Text(
                '${c.legs[i]} Legs · ${c.sets[i]} Sets\n3DA: '
                '${statistics.players[i].average?.toStringAsFixed(2) ?? '—'}',
              ),
              trailing: Text(
                '${i == c.activePlayer && c.winner == null ? c.remaining : c.scores[i]}',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (c.winner != null)
          Text(
            '${widget.settings.participants[c.winner!].name} gewinnt!',
            style: Theme.of(context).textTheme.headlineSmall,
          )
        else ...[
          Text(
            '${widget.settings.participants[c.activePlayer].name} ist am Wurf${c.isBotTurn ? ' · Bot' : ''}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (c.isBotTurn) const LinearProgressIndicator(),
        ],
        const SizedBox(height: 12),
        Text(c.message),
        TextButton.icon(
          onPressed: _showStatistics,
          icon: const Icon(Icons.bar_chart),
          label: Text(
            c.winner == null ? 'Live-Statistik' : 'Spielauswertung ansehen',
          ),
        ),
        const SizedBox(height: 12),
        if (c.winner == null)
          CheckoutRoutes(
            score: c.remaining,
            dartsLeft: c.dartsLeft,
            requirement: widget.settings.checkoutRequirement,
          ),
      ],
    );
    final pad = Column(
      children: [
        ScoreKeypad(
          enabled: c.winner == null && !c.isBotTurn,
          remaining: c.remaining,
          onSubmit: _submit,
          onBust: _submitBust,
          onUndo: c.canUndo ? c.undo : null,
        ),
        const Text(
          'Summe der Aufnahme eingeben und mit OK bestätigen.\nTastatur: Ziffern, Enter, Rücktaste, Esc.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'Die laufende Partie wird beim Verlassen beendet.',
          textAlign: TextAlign.center,
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('X01 Scorer'),
        actions: [
          IconButton(
            tooltip: 'Matchstatistik',
            onPressed: _showStatistics,
            icon: const Icon(Icons.bar_chart),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: constraints.maxWidth >= 760
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: board),
                          const SizedBox(width: 24),
                          Expanded(child: pad),
                        ],
                      )
                    : Column(
                        children: [board, const SizedBox(height: 16), pad],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
