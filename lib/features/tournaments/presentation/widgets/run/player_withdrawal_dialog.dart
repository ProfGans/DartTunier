import 'package:flutter/material.dart';
import '../../../domain/player_withdrawal.dart';
import '../../../domain/tournament_models.dart';
import '../../../application/player_withdrawal_service.dart';

class PlayerWithdrawalDialog extends StatefulWidget {
  const PlayerWithdrawalDialog({super.key, required this.tournament});
  final CreatedTournament tournament;
  @override
  State<PlayerWithdrawalDialog> createState() => _WithdrawalState();
}

class _WithdrawalState extends State<PlayerWithdrawalDialog> {
  TournamentPlayer? player;
  WithdrawalResultMode mode = WithdrawalResultMode.loseOpen;
  bool ranking = false, opponents = true;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Spieler aus Turnier entfernen'),
    scrollable: true,
    content: SizedBox(
      width: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<TournamentPlayer>(
            itemHeight: null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Spieler / Team'),
            items: [
              for (final p in widget.tournament.players)
                if (PlayerWithdrawalService.policy(widget.tournament, p) ==
                    null)
                  DropdownMenuItem(value: p, child: Text(p.name)),
            ],
            onChanged: (p) => setState(() => player = p),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<WithdrawalResultMode>(
            itemHeight: null,
            initialValue: mode,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Spielwertung'),
            items: [
              for (final v in WithdrawalResultMode.values)
                DropdownMenuItem(
                  value: v,
                  child: Text(switch (v) {
                    WithdrawalResultMode.loseOpen =>
                      'Offene Spiele zu Null verlieren',
                    WithdrawalResultMode.loseAll =>
                      'Alle Spiele zu Null verlieren',
                    WithdrawalResultMode.ignoreOpen =>
                      'Offene Spiele nicht werten',
                    WithdrawalResultMode.ignoreAll =>
                      'Alle Spiele nicht werten',
                  }),
                ),
            ],
            onChanged: (v) => setState(() => mode = v!),
          ),
          const SizedBox(height: 12),
          const Text(
            '„Alle Spiele“ betrifft auch bisherige Ergebnisse. Wenn frühere Etappen betroffen sind, werden die davon abhängigen späteren Etappen neu aufgebaut und ihre Ergebnisse zurückgesetzt. Im K.-o.-Baum kommt der Gegner eines offenen Spiels kampflos weiter.',
          ),
          if (widget.tournament.communityId != null) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ausgeschiedenen Spieler für Rangliste werten'),
              value: ranking,
              onChanged: (v) => setState(() => ranking = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ergebnisse der Gegner für Rangliste werten'),
              subtitle: const Text(
                'Tatsächliche Ergebnisse und gewertete Zu-null-Niederlagen. Ignorierte offene Spiele geben keine Elo-Punkte.',
              ),
              value: opponents,
              onChanged: (v) => setState(() => opponents = v),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        onPressed: player == null
            ? null
            : () => Navigator.pop(
                context,
                PlayerWithdrawal(
                  playerKey: PlayerWithdrawalService.key(player!),
                  mode: mode,
                  createdAt: DateTime.now(),
                  countForRanking: ranking,
                  countOpponentsForRanking: opponents,
                ),
              ),
        child: const Text('Entfernen und Wertung anwenden'),
      ),
    ],
  );
}
