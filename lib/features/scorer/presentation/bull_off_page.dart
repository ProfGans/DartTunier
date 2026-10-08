import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../shared/widgets/adaptive_content.dart';
import '../domain/bot/bot_engine.dart';
import '../domain/bull_off.dart';
import '../domain/scorer_settings.dart';
import '../domain/x01/x01_models.dart';

class BullOffPage extends StatefulWidget {
  const BullOffPage({super.key, required this.rule, required this.players});
  final BullOffRule rule;
  final List<ScorerParticipant> players;

  @override
  State<BullOffPage> createState() => _BullOffPageState();
}

class _BullOffPageState extends State<BullOffPage> {
  late final game = BullOff(rule: widget.rule, players: widget.players.length);
  final distance = TextEditingController();
  final bots = BotEngine();
  Timer? timer;
  String? error;

  @override
  void initState() {
    super.initState();
    _scheduleBot();
  }

  void _scheduleBot() {
    timer?.cancel();
    final index = game.current;
    if (index == null || widget.players[index].bot == null) return;
    timer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted || game.current != index) return;
      final shot = bots.simulateTargetThrow(
        target: const DartThrowResult(
          label: 'Bull',
          baseValue: 25,
          scoredPoints: 50,
          isDouble: true,
          isTriple: false,
          isBull: true,
        ),
        score: 50,
        profile: widget.players[index].bot!,
      );
      final dx = shot.hitPoint.x - bots.boardGeometry.center.x;
      final dy = shot.hitPoint.y - bots.boardGeometry.center.y;
      final radius = sqrt(dx * dx + dy * dy);
      // A dart must remain in the board. Retry simulated off-board darts.
      if (radius > bots.boardGeometry.radii.boardOuter) {
        _scheduleBot();
        return;
      }
      _record(
        shot.hit.isBull
            ? const BullOffHit.bull()
            : shot.hit.label == '25'
            ? const BullOffHit.outerBull()
            : BullOffHit.outside(
                max(16, radius * 170 / bots.boardGeometry.radii.doubleOuter),
              ),
      );
    });
  }

  void _record(BullOffHit hit) {
    setState(() {
      game.record(hit);
      distance.clear();
      error = null;
    });
    _scheduleBot();
  }

  @override
  void dispose() {
    timer?.cancel();
    distance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = game.current;
    final winner = game.winner;
    return Scaffold(
      appBar: AppBar(title: Text('Ausbullen · ${widget.rule.label}')),
      body: AdaptiveContentList(
        maxWidth: 900,
        children: [
          Text(widget.rule.description),
          const SizedBox(height: 12),
          const Text(
            'Die erste Wurfreihenfolge wurde ausgelost. Pro Spieler oder '
            'Doppelteam wirft eine Person einen Dart. Bull und 25 vor dem '
            'nächsten Wurf herausnehmen. Abpraller erneut werfen, bis der Dart steckt.',
          ),
          if (widget.players.length > 2)
            const Text(
              'Mehrspieler-Erweiterung: Nur die Bestplatzierten werfen '
              'bei Gleichstand erneut. Die übrige Spielreihenfolge bleibt erhalten.',
            ),
          const SizedBox(height: 24),
          Text(
            'Runde ${game.round}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          for (final index in game.order)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                index == current ? Icons.arrow_forward : Icons.person,
              ),
              title: Text(widget.players[index].name),
              subtitle: Text(
                game.hits[index]?.label(widget.rule) ?? 'Wurf steht aus',
              ),
            ),
          if (current != null) ...[
            const SizedBox(height: 16),
            Text(
              '${widget.players[current].name} wirft auf Bull',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (widget.players[current].bot != null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              )
            else ...[
              const Text('Treffer am Board ablesen und hier eintragen.'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _button('Bull · 50', () => _record(const BullOffHit.bull())),
                  _button(
                    'Outer Bull · 25',
                    () => _record(const BullOffHit.outerBull()),
                  ),
                  if (widget.rule == BullOffRule.pdc)
                    _button('Außerhalb', () => _record(BullOffHit.outside())),
                ],
              ),
              if (widget.rule == BullOffRule.wdf) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: distance,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Außerhalb: Abstand zur Mitte in mm',
                    helperText:
                        'Gleich weit / nicht unterscheidbar: gleichen Abstand eintragen.',
                    helperMaxLines: 3,
                    errorText: error,
                  ),
                ),
                _button('Abstand übernehmen', () {
                  final value = double.tryParse(
                    distance.text.replaceAll(',', '.'),
                  );
                  if (value == null || !value.isFinite || value <= 15.9) {
                    setState(
                      () => error = 'Abstand größer als 15,9 mm eingeben.',
                    );
                    return;
                  }
                  _record(BullOffHit.outside(value));
                }),
              ],
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Derselbe Spieler wirft erneut.'),
                  ),
                ),
                child: const Text(
                  'Abpraller / Dart steckt nicht – erneut werfen',
                ),
              ),
            ],
          ],
          if (winner == null && game.hits.isNotEmpty)
            TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () {
                timer?.cancel();
                setState(game.undo);
                _scheduleBot();
              },
              icon: const Icon(Icons.undo),
              label: const Text('Letzten Eintrag zurücknehmen'),
            ),
          if (game.ready && winner == null)
            _button('Runde auswerten', () {
              setState(game.resolve);
              _scheduleBot();
            }),
          if (winner != null) ...[
            const SizedBox(height: 24),
            Text(
              '${widget.players[winner].name} gewinnt das Ausbullen',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (widget.rule == BullOffRule.pdc &&
                widget.players[winner].bot == null) ...[
              const Text('Der Gewinner entscheidet, wer das Spiel beginnt.'),
              for (var i = 0; i < widget.players.length; i++)
                _button(
                  '${widget.players[i].name} beginnt',
                  () => Navigator.of(context).pop(i),
                ),
            ] else
              _button(
                '${widget.players[winner].name} beginnt · Spiel starten',
                () => Navigator.of(context).pop(winner),
              ),
          ],
        ],
      ),
    );
  }

  Widget _button(String label, VoidCallback action) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: FilledButton(
      onPressed: action,
      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      child: Text(label),
    ),
  );
}
