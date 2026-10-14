import 'package:flutter/material.dart';

import '../../../domain/tournament_models.dart';
import '../../../../statistics/domain/best_performance.dart';

class BestPerformanceEditor extends StatefulWidget {
  const BestPerformanceEditor({
    super.key,
    required this.match,
    required this.initial,
    required this.onChanged,
  });

  final GroupMatch match;
  final List<BestPerformance> initial;
  final ValueChanged<List<BestPerformance>> onChanged;

  @override
  State<BestPerformanceEditor> createState() => _BestPerformanceEditorState();
}

class _BestPerformanceEditorState extends State<BestPerformanceEditor> {
  late final List<BestPerformance> _items = [...widget.initial];
  BestPerformanceType _type = BestPerformanceType.score180;
  String? _playerId;
  final TextEditingController _value = TextEditingController();

  List<TournamentPlayer> get _players => [
    if (widget.match.homePlayer != null) widget.match.homePlayer!,
    if (widget.match.awayPlayer != null) widget.match.awayPlayer!,
  ];

  @override
  void initState() {
    super.initState();
    final home = widget.match.homePlayer;
    _playerId = home == null ? null : (home.profileId ?? home.name);
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _add() {
    final players = _players;
    if (players.isEmpty) return;
    final player = players.firstWhere(
      (candidate) => (candidate.profileId ?? candidate.name) == _playerId,
      orElse: () => players.first,
    );
    final value = int.tryParse(_value.text.trim());
    if ((_type == BestPerformanceType.highFinish &&
            (value == null || value < 100 || value > 170)) ||
        (_type == BestPerformanceType.shortLeg &&
            (value == null || value < 1 || value > 18))) {
      return;
    }
    setState(() {
      _items.add(BestPerformance(
        type: _type,
        playerName: player.name,
        playerProfileId: player.profileId,
        value: value,
      ));
      _value.clear();
    });
    widget.onChanged(List.unmodifiable(_items));
  }

  @override
  Widget build(BuildContext context) {
    final players = _players;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_items.isNotEmpty)
          for (var index = 0; index < _items.length; index++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${_items[index].playerName}: ${_items[index].label}'
                  '${_items[index].value == null ? '' : ' ${_items[index].value}'}'),
              trailing: IconButton(
                tooltip: 'Bestleistung entfernen',
                onPressed: () {
                  setState(() => _items.removeAt(index));
                  widget.onChanged(List.unmodifiable(_items));
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ),
        if (players.isNotEmpty)
          DropdownButtonFormField<String?>(
            value: _playerId,
            decoration: const InputDecoration(labelText: 'Spieler'),
            items: [
              for (final player in players)
                DropdownMenuItem<String?>(
                  value: player.profileId ?? player.name,
                  child: Text(player.name),
                ),
            ],
            onChanged: (value) => setState(() => _playerId = value),
          ),
        const SizedBox(height: 8),
        DropdownButtonFormField<BestPerformanceType>(
          value: _type,
          decoration: const InputDecoration(labelText: 'Bestleistung'),
          items: [
            for (final type in BestPerformanceType.values)
              DropdownMenuItem(value: type, child: Text(_label(type))),
          ],
          onChanged: (value) => setState(() => _type = value ?? _type),
        ),
        if (_type == BestPerformanceType.highFinish ||
            _type == BestPerformanceType.shortLeg) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _value,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _type == BestPerformanceType.highFinish
                  ? 'Finish (100–170)'
                  : 'Darts (1–18)',
            ),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: players.isEmpty ? null : _add,
          icon: const Icon(Icons.add),
          label: const Text('Bestleistung hinzufügen'),
        ),
      ],
    );
  }

  String _label(BestPerformanceType type) => switch (type) {
    BestPerformanceType.score170 => '170+ Aufnahme',
    BestPerformanceType.score180 => '180+ Aufnahme',
    BestPerformanceType.highFinish => 'High Finish (100+)',
    BestPerformanceType.shortLeg => 'Shortleg (18 Darts oder weniger)',
  };
}
