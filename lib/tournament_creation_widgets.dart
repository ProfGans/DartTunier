part of 'main.dart';

class _RenamePlayerDialog extends StatefulWidget {
  const _RenamePlayerDialog({required this.player});

  final TournamentPlayer player;

  @override
  State<_RenamePlayerDialog> createState() => _RenamePlayerDialogState();
}

class _RenamePlayerDialogState extends State<_RenamePlayerDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.player.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_nameController.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Spieler bearbeiten'),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Spielername',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Speichern')),
      ],
    );
  }
}

class _GroupSizePreview extends StatelessWidget {
  const _GroupSizePreview({required this.groupSizes});

  final List<int> groupSizes;

  @override
  Widget build(BuildContext context) {
    if (groupSizes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 14),
        child: Text('Erst Spieler anlegen.'),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < groupSizes.length; index++)
          Chip(
            avatar: CircleAvatar(child: Text('${index + 1}')),
            label: Text('${groupSizes[index]} Spieler'),
          ),
      ],
    );
  }
}

class _RoundRobinRepeatsSetup extends StatelessWidget {
  const _RoundRobinRepeatsSetup({
    required this.groupSizes,
    required this.playTypes,
    required this.repeats,
    required this.onChangeRepeats,
  });

  final List<int> groupSizes;
  final List<String> playTypes;
  final List<int> repeats;
  final void Function(int groupIndex, int delta) onChangeRepeats;

  @override
  Widget build(BuildContext context) {
    if (groupSizes.isEmpty || !playTypes.contains('round_robin')) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Begegnungen pro Paar',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < groupSizes.length; index++)
              if (index < playTypes.length && playTypes[index] == 'round_robin')
                Container(
                  padding: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(groupLabel(index + 1)),
                      const SizedBox(width: 8),
                      IconButton(
                        key: ValueKey('round-robin-repeat-minus-${index + 1}'),
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 36,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: repeats[index] <= 1
                            ? null
                            : () => onChangeRepeats(index, -1),
                        icon: const Icon(Icons.remove),
                        tooltip: 'Weniger Spiele',
                      ),
                      Text('${repeats[index]}x'),
                      IconButton(
                        key: ValueKey('round-robin-repeat-plus-${index + 1}'),
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 36,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () => onChangeRepeats(index, 1),
                        icon: const Icon(Icons.add),
                        tooltip: 'Mehr Spiele',
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ],
    );
  }
}

class _GroupPlayTypeSetup extends StatelessWidget {
  const _GroupPlayTypeSetup({
    required this.groupSizes,
    required this.playTypes,
    required this.onChanged,
  });

  final List<int> groupSizes;
  final List<String> playTypes;
  final void Function(int groupIndex, String playType) onChanged;

  @override
  Widget build(BuildContext context) {
    if (groupSizes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Spieltyp je Gruppe', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < groupSizes.length; index++)
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(
                    'group-play-type-${index + 1}-${playTypes[index]}',
                  ),
                  isExpanded: true,
                  initialValue: playTypes[index],
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: groupLabel(index + 1),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'round_robin',
                      child: Text('Liga'),
                    ),
                    DropdownMenuItem(
                      value: 'mini_knockout',
                      child: Text('Mini-KO'),
                    ),
                    DropdownMenuItem(
                      value: 'double_knockout',
                      child: Text('Doppel-KO'),
                    ),
                    DropdownMenuItem(
                      value: 'triple_knockout',
                      child: Text('Triple-KO'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onChanged(index, value);
                    }
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StageMatchCountPreview extends StatelessWidget {
  const _StageMatchCountPreview({
    required this.matchCount,
    required this.details,
  });

  final int matchCount;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sports_score_outlined, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$matchCount Spiele in dieser Etappe',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final detail in details)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(detail),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KnockoutPreview extends StatelessWidget {
  const _KnockoutPreview({
    required this.participantCount,
    required this.bracketSize,
    required this.byeCount,
    required this.eliminationLossLimit,
    required this.seedingMode,
    required this.slotOrder,
    required this.participantLabels,
    required this.onSeedingModeChanged,
    required this.onSwapSlot,
    required this.onResetSlots,
  });

  final int? participantCount;
  final int? bracketSize;
  final int byeCount;
  final int eliminationLossLimit;
  final String seedingMode;
  final List<int?> slotOrder;
  final List<String> participantLabels;
  final ValueChanged<String> onSeedingModeChanged;
  final void Function(int fromIndex, int toIndex) onSwapSlot;
  final VoidCallback onResetSlots;

  @override
  Widget build(BuildContext context) {
    if (participantCount == null || bracketSize == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 14),
        child: Text('Mindestens 2 Teilnehmer.'),
      );
    }

    final resolvedParticipantCount = participantCount!;
    final resolvedBracketSize = bracketSize!;
    final slots = slotOrder.length == resolvedBracketSize
        ? slotOrder
        : List<int?>.generate(
            resolvedBracketSize,
            (index) => index < resolvedParticipantCount ? index + 1 : null,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text('$resolvedParticipantCount Weiter')),
            Chip(label: Text('${resolvedBracketSize}er Feld')),
            Chip(label: Text('$byeCount Freilose')),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'cross',
              icon: Icon(Icons.swap_horiz),
              label: Text('Cross seeded'),
            ),
            ButtonSegment(
              value: 'random',
              icon: Icon(Icons.shuffle),
              label: Text('Zufall'),
            ),
          ],
          selected: {seedingMode},
          onSelectionChanged: (selection) {
            onSeedingModeChanged(selection.first);
          },
        ),
        if (seedingMode == 'cross' && byeCount > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Cross Seed vergibt Freilose automatisch an die bestplatzierten Teilnehmer.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'Bracket-Vorschau',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              onPressed: onResetSlots,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Auto'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (eliminationLossLimit == 2)
          _DoubleEliminationPreview(
            bracketSize: resolvedBracketSize,
            slotOrder: slots,
            participantLabels: participantLabels,
            onSwapSlot: onSwapSlot,
          )
        else if (eliminationLossLimit == 3)
          _TripleEliminationPreview(
            bracketSize: resolvedBracketSize,
            slotOrder: slots,
            participantLabels: participantLabels,
            onSwapSlot: onSwapSlot,
          )
        else
          _CompactKnockoutPreviewTree(
            bracketSize: resolvedBracketSize,
            slotOrder: slots,
            participantLabels: participantLabels,
            onSwapSlot: onSwapSlot,
            showOnlyFirstRound: eliminationLossLimit > 1,
          ),
      ],
    );
  }
}

class _TripleEliminationPreview extends StatelessWidget {
  const _TripleEliminationPreview({
    required this.bracketSize,
    required this.slotOrder,
    required this.participantLabels,
    required this.onSwapSlot,
  });

  final int bracketSize;
  final List<int?> slotOrder;
  final List<String> participantLabels;
  final void Function(int fromIndex, int toIndex) onSwapSlot;

  @override
  Widget build(BuildContext context) {
    final roundCount = _log2PowerOfTwo(bracketSize);
    final roundTitles = <String>[_lossLevelMatchLabel(0, 1)];
    final roundCards = <List<Widget>>[
      [
        for (var matchIndex = 0; matchIndex < bracketSize ~/ 2; matchIndex++)
          _BracketPreviewMatch(
            matchNumber: matchIndex + 1,
            topSlotIndex: matchIndex * 2,
            bottomSlotIndex: matchIndex * 2 + 1,
            slotOrder: slotOrder,
            participantLabels: participantLabels,
            onSwapSlot: onSwapSlot,
          ),
      ],
    ];

    for (var roundNumber = 2; roundNumber <= roundCount; roundNumber++) {
      roundTitles.add(_lossLevelMatchLabel(0, roundNumber));
      roundCards.add([
        for (var index = 0;
            index < (bracketSize >> roundNumber).clamp(1, bracketSize).toInt();
            index++)
          _BracketPreviewPlaceholderMatch(matchNumber: index + 1),
      ]);
    }

    for (var lossCount = 1; lossCount < 3; lossCount++) {
      for (var roundNumber = 1;
          roundNumber <= roundCount + lossCount;
          roundNumber++) {
        roundTitles.add(_lossLevelMatchLabel(lossCount, roundNumber));
        roundCards.add([
          for (var index = 0;
              index <
                  _triplePreviewMatchCount(
                    bracketSize,
                    lossCount,
                    roundNumber,
                  );
              index++)
            _BracketPreviewPlaceholderMatch(matchNumber: index + 1),
        ]);
      }
    }

    roundTitles.add(_tripleFinalLabel);
    roundCards.add([const _BracketPreviewPlaceholderMatch(matchNumber: 1)]);

    return _BracketTreeLayout(
      totalRounds: roundTitles.length,
      roundTitles: roundTitles,
      roundCards: roundCards,
      columnWidth: 170,
      cardHeight: 108,
      firstRoundGap: 10,
      useBalancedColumnLayout: true,
    );
  }

  int _triplePreviewMatchCount(
    int bracketSize,
    int lossCount,
    int roundNumber,
  ) {
    final divisor = 1 << (roundNumber + lossCount);
    return (bracketSize ~/ divisor).clamp(1, bracketSize ~/ 2).toInt();
  }
}

class _DoubleEliminationPreview extends StatelessWidget {
  const _DoubleEliminationPreview({
    required this.bracketSize,
    required this.slotOrder,
    required this.participantLabels,
    required this.onSwapSlot,
  });

  final int bracketSize;
  final List<int?> slotOrder;
  final List<String> participantLabels;
  final void Function(int fromIndex, int toIndex) onSwapSlot;

  @override
  Widget build(BuildContext context) {
    final winnersRoundCount = _log2PowerOfTwo(bracketSize);
    final winnersTitles = <String>['Winners Runde 1'];
    final winnersCards = <List<Widget>>[
      _firstRoundPreviewCards(),
    ];
    final losersTitles = <String>[];
    final losersCards = <List<Widget>>[];

    var losersRoundNumber = 1;
    for (var winnersRoundNumber = 2;
        winnersRoundNumber <= winnersRoundCount;
        winnersRoundNumber++) {
      final winnersMatchCount = bracketSize >> winnersRoundNumber;
      winnersTitles.add('Winners Runde $winnersRoundNumber');
      winnersCards.add([
        for (var index = 0; index < winnersMatchCount; index++)
          _BracketPreviewPlaceholderMatch(matchNumber: index + 1),
      ]);

      if (winnersRoundNumber == 2) {
        final initialLosersMatchCount = bracketSize >> 2;
        losersTitles.add('Losers Runde $losersRoundNumber');
        losersCards.add([
          for (var index = 0; index < initialLosersMatchCount; index++)
            _BracketPreviewPlaceholderMatch(matchNumber: index + 1),
        ]);
        losersRoundNumber++;
      }

      losersTitles.add('Losers Runde $losersRoundNumber');
      losersCards.add([
        for (var index = 0; index < winnersMatchCount; index++)
          _BracketPreviewPlaceholderMatch(matchNumber: index + 1),
      ]);
      losersRoundNumber++;

      if (winnersRoundNumber < winnersRoundCount) {
        losersTitles.add('Losers Runde $losersRoundNumber');
        losersCards.add([
          for (var index = 0; index < winnersMatchCount ~/ 2; index++)
            _BracketPreviewPlaceholderMatch(matchNumber: index + 1),
        ]);
        losersRoundNumber++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BracketBandTitle(title: 'Winners Bracket'),
        const SizedBox(height: 8),
        _BracketTreeLayout(
          totalRounds: winnersTitles.length,
          roundTitles: winnersTitles,
          roundCards: winnersCards,
          columnWidth: 170,
          cardHeight: 108,
          firstRoundGap: 10,
          useBalancedColumnLayout: true,
        ),
        const SizedBox(height: 16),
        const _BracketBandTitle(title: 'Losers Bracket'),
        const SizedBox(height: 8),
        _BracketTreeLayout(
          totalRounds: losersTitles.length,
          roundTitles: losersTitles,
          roundCards: losersCards,
          columnWidth: 170,
          cardHeight: 108,
          firstRoundGap: 10,
          useBalancedColumnLayout: true,
        ),
        const SizedBox(height: 16),
        const _BracketBandTitle(title: 'Finale'),
        const SizedBox(height: 8),
        _BracketTreeLayout(
          totalRounds: 1,
          roundTitles: const ['Grand Final'],
          roundCards: const [
            [_BracketPreviewPlaceholderMatch(matchNumber: 1)],
          ],
          columnWidth: 170,
          cardHeight: 108,
          firstRoundGap: 10,
          useBalancedColumnLayout: true,
        ),
      ],
    );
  }

  List<Widget> _firstRoundPreviewCards() {
    return [
      for (var matchIndex = 0; matchIndex < bracketSize ~/ 2; matchIndex++)
        _BracketPreviewMatch(
          matchNumber: matchIndex + 1,
          topSlotIndex: matchIndex * 2,
          bottomSlotIndex: matchIndex * 2 + 1,
          slotOrder: slotOrder,
          participantLabels: participantLabels,
          onSwapSlot: onSwapSlot,
        ),
    ];
  }
}

class _CompactKnockoutPreviewTree extends StatelessWidget {
  const _CompactKnockoutPreviewTree({
    required this.bracketSize,
    required this.slotOrder,
    required this.participantLabels,
    required this.onSwapSlot,
    this.showOnlyFirstRound = false,
  });

  final int bracketSize;
  final List<int?> slotOrder;
  final List<String> participantLabels;
  final void Function(int fromIndex, int toIndex) onSwapSlot;
  final bool showOnlyFirstRound;

  @override
  Widget build(BuildContext context) {
    final roundSizes = <int>[];
    var matchesInRound = bracketSize ~/ 2;
    while (matchesInRound >= 1) {
      roundSizes.add(matchesInRound);
      if (showOnlyFirstRound) {
        break;
      }
      matchesInRound ~/= 2;
    }

    return _BracketTreeLayout(
      totalRounds: roundSizes.length,
      columnWidth: 160,
      cardHeight: 108,
      firstRoundGap: 10,
      roundTitles: [
        for (var roundIndex = 0; roundIndex < roundSizes.length; roundIndex++)
          showOnlyFirstRound
              ? 'Runde 1'
              : _bracketRoundTitle(roundIndex, roundSizes.length),
      ],
      roundCards: [
        for (var roundIndex = 0; roundIndex < roundSizes.length; roundIndex++)
          [
            for (
              var matchIndex = 0;
              matchIndex < roundSizes[roundIndex];
              matchIndex++
            )
              if (roundIndex == 0)
                _BracketPreviewMatch(
                  matchNumber: matchIndex + 1,
                  topSlotIndex: matchIndex * 2,
                  bottomSlotIndex: matchIndex * 2 + 1,
                  slotOrder: slotOrder,
                  participantLabels: participantLabels,
                  onSwapSlot: onSwapSlot,
                )
              else
                _BracketPreviewPlaceholderMatch(matchNumber: matchIndex + 1),
          ],
      ],
    );
  }
}
class _BracketPreviewPlaceholderMatch extends StatelessWidget {
  const _BracketPreviewPlaceholderMatch({required this.matchNumber});

  final int matchNumber;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Spiel $matchNumber',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 6),
          _BracketPreviewOpenSlot(),
          const SizedBox(height: 5),
          _BracketPreviewOpenSlot(),
        ],
      ),
    );
  }
}

class _BracketPreviewOpenSlot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text('offen'),
    );
  }
}

class _BracketPreviewMatch extends StatelessWidget {
  const _BracketPreviewMatch({
    required this.matchNumber,
    required this.topSlotIndex,
    required this.bottomSlotIndex,
    required this.slotOrder,
    required this.participantLabels,
    required this.onSwapSlot,
  });

  final int matchNumber;
  final int topSlotIndex;
  final int bottomSlotIndex;
  final List<int?> slotOrder;
  final List<String> participantLabels;
  final void Function(int fromIndex, int toIndex) onSwapSlot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Spiel $matchNumber',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          _BracketPreviewSlot(
            slotIndex: topSlotIndex,
            slotCount: slotOrder.length,
            seed: slotOrder[topSlotIndex],
            label: _slotLabel(slotOrder[topSlotIndex]),
            onSwapSlot: onSwapSlot,
          ),
          const SizedBox(height: 5),
          _BracketPreviewSlot(
            slotIndex: bottomSlotIndex,
            slotCount: slotOrder.length,
            seed: slotOrder[bottomSlotIndex],
            label: _slotLabel(slotOrder[bottomSlotIndex]),
            onSwapSlot: onSwapSlot,
          ),
        ],
      ),
    );
  }

  String _slotLabel(int? seed) {
    if (seed == null) {
      return 'Freilos';
    }

    final labelIndex = seed - 1;
    if (labelIndex >= 0 && labelIndex < participantLabels.length) {
      return participantLabels[labelIndex];
    }

    return 'Platz $seed';
  }
}

class _BracketPreviewSlot extends StatelessWidget {
  const _BracketPreviewSlot({
    required this.slotIndex,
    required this.slotCount,
    required this.seed,
    required this.label,
    required this.onSwapSlot,
  });

  final int slotIndex;
  final int slotCount;
  final int? seed;
  final String label;
  final void Function(int fromIndex, int toIndex) onSwapSlot;

  @override
  Widget build(BuildContext context) {
    final isBye = seed == null;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 28,
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: isBye
            ? colorScheme.surfaceContainerHighest
            : const Color(0xFFC8F7DC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isBye ? colorScheme.outlineVariant : const Color(0xFF14965F),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            constraints: const BoxConstraints.tightFor(width: 24, height: 28),
            padding: EdgeInsets.zero,
            onPressed: slotIndex == 0
                ? null
                : () => onSwapSlot(slotIndex, slotIndex - 1),
            icon: const Icon(Icons.keyboard_arrow_up, size: 18),
            tooltip: 'Slot nach oben',
          ),
          IconButton(
            constraints: const BoxConstraints.tightFor(width: 24, height: 28),
            padding: EdgeInsets.zero,
            onPressed: slotIndex >= slotCount - 1
                ? null
                : () => onSwapSlot(slotIndex, slotIndex + 1),
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
            tooltip: 'Slot nach unten',
          ),
        ],
      ),
    );
  }
}

class _GroupTieBreakerSetup extends StatelessWidget {
  const _GroupTieBreakerSetup({
    required this.tieBreakers,
    required this.onMoveTieBreaker,
  });

  final List<String> tieBreakers;
  final void Function(int index, int direction) onMoveTieBreaker;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tie-Breaker', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < tieBreakers.length; index++)
              Container(
                padding: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 12, child: Text('${index + 1}')),
                    const SizedBox(width: 8),
                    Text(tieBreakerLabel(tieBreakers[index])),
                    IconButton(
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 36,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: index == 0
                          ? null
                          : () => onMoveTieBreaker(index, -1),
                      icon: const Icon(Icons.keyboard_arrow_up),
                      tooltip: 'Tie-Breaker nach oben',
                    ),
                    IconButton(
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 36,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: index == tieBreakers.length - 1
                          ? null
                          : () => onMoveTieBreaker(index, 1),
                      icon: const Icon(Icons.keyboard_arrow_down),
                      tooltip: 'Tie-Breaker nach unten',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _GroupQualificationSetup extends StatelessWidget {
  const _GroupQualificationSetup({
    required this.groupSizes,
    required this.groupPlayTypes,
    required this.qualificationPlan,
    required this.autoAdjust,
    required this.bestOfQualifierCountController,
    required this.onSetExtraGroup,
    required this.onCyclePlace,
    required this.onAutoAdjustChanged,
    required this.onBestOfQualifierCountChanged,
  });

  final List<int> groupSizes;
  final List<String> groupPlayTypes;
  final QualificationPlan? qualificationPlan;
  final bool autoAdjust;
  final TextEditingController bestOfQualifierCountController;
  final void Function(int groupNumber, bool selected, List<int> currentGroups)
  onSetExtraGroup;
  final void Function(int groupNumber, int place) onCyclePlace;
  final ValueChanged<bool> onAutoAdjustChanged;
  final ValueChanged<String> onBestOfQualifierCountChanged;

  int _selectedQualifierCount(QualificationPlan plan) {
    final fixedTotal = plan.fixedByGroup.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    return fixedTotal + plan.extraCount.clamp(0, plan.extraGroups.length);
  }

  List<String> _validationMessages(QualificationPlan? plan) {
    if (autoAdjust || plan == null) {
      return const [];
    }

    final selectedCount = _selectedQualifierCount(plan);
    final fixedTotal = plan.fixedByGroup.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    if (fixedTotal > plan.totalQualifiers) {
      return [
        'Es sind ${fixedTotal - plan.totalQualifiers} feste Plaetze zu viel markiert.',
      ];
    }

    if (plan.extraGroups.length < plan.extraCount) {
      return [
        'Es fehlen ${plan.extraCount - plan.extraGroups.length} Gruppen fuer den Beste-${plan.extraCount}-Vergleich.',
      ];
    }

    if (selectedCount == plan.totalQualifiers) {
      return const [];
    }

    if (selectedCount < plan.totalQualifiers) {
      return [
        'Es kommen noch ${plan.totalQualifiers - selectedCount} Spieler zu wenig weiter. Erhoehe "Beste-N Weiter" oder markiere feste Plaetze.',
      ];
    }

    return [
      'Es kommen ${selectedCount - plan.totalQualifiers} Spieler zu viel weiter. Reduziere "Beste-N Weiter" oder feste Plaetze.',
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (groupSizes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Erst Spieler und Gruppen anlegen.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Weiterkommensregel',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                icon: Icon(Icons.auto_fix_high_outlined),
                label: Text('Automatik'),
              ),
              ButtonSegment(
                value: false,
                icon: Icon(Icons.tune_outlined),
                label: Text('Manuell'),
              ),
            ],
            selected: {autoAdjust},
            onSelectionChanged: (selection) {
              onAutoAdjustChanged(selection.first);
            },
          ),
        ),
        const SizedBox(height: 8),
        _QualificationRuleSummary(qualificationPlan: qualificationPlan),
        if (qualificationPlan != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: 180,
            child: TextField(
              controller: bestOfQualifierCountController,
              enabled: !autoAdjust,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Beste-N Weiter',
                prefixIcon: Icon(Icons.workspace_premium_outlined),
              ),
              onChanged: onBestOfQualifierCountChanged,
            ),
          ),
        ],
        for (final message in _validationMessages(qualificationPlan)) ...[
          const SizedBox(height: 8),
          _QualificationErrorBanner(message: message),
        ],
        const SizedBox(height: 12),
        _QualificationGroupPreview(
          groupSizes: groupSizes,
          groupPlayTypes: groupPlayTypes,
          qualificationPlan: qualificationPlan,
          onCyclePlace: onCyclePlace,
        ),
        if (qualificationPlan != null && qualificationPlan!.extraCount > 0) ...[
          const SizedBox(height: 12),
          Text(
            'Gruppen im Beste-${qualificationPlan!.extraCount}-Vergleich',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < groupSizes.length; index++)
                FilterChip(
                  key: ValueKey('extra-group-chip-${index + 1}'),
                  label: Text(groupLabel(index + 1)),
                  selected: qualificationPlan!.extraGroups.contains(index + 1),
                  onSelected: groupSizes[index] < qualificationPlan!.extraRank
                      ? null
                      : (selected) => onSetExtraGroup(
                          index + 1,
                          selected,
                          qualificationPlan!.extraGroups,
                        ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _QualificationErrorBanner extends StatelessWidget {
  const _QualificationErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _QualificationGroupPreview extends StatelessWidget {
  const _QualificationGroupPreview({
    required this.groupSizes,
    required this.groupPlayTypes,
    required this.qualificationPlan,
    required this.onCyclePlace,
  });

  final List<int> groupSizes;
  final List<String> groupPlayTypes;
  final QualificationPlan? qualificationPlan;
  final void Function(int groupNumber, int place) onCyclePlace;

  @override
  Widget build(BuildContext context) {
    final plan = qualificationPlan;
    if (plan == null) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (var groupIndex = 0; groupIndex < groupSizes.length; groupIndex++)
          _QualificationGroupCard(
            groupNumber: groupIndex + 1,
            playerCount: groupSizes[groupIndex],
            playType: groupIndex < groupPlayTypes.length
                ? groupPlayTypes[groupIndex]
                : 'round_robin',
            qualificationPlan: plan,
            onCyclePlace: onCyclePlace,
          ),
      ],
    );
  }
}

class _QualificationGroupCard extends StatelessWidget {
  const _QualificationGroupCard({
    required this.groupNumber,
    required this.playerCount,
    required this.playType,
    required this.qualificationPlan,
    required this.onCyclePlace,
  });

  final int groupNumber;
  final int playerCount;
  final String playType;
  final QualificationPlan qualificationPlan;
  final void Function(int groupNumber, int place) onCyclePlace;

  int get _fixedForGroup {
    if (groupNumber - 1 < qualificationPlan.fixedByGroup.length) {
      return qualificationPlan.fixedByGroup[groupNumber - 1];
    }
    return qualificationPlan.fixedPerGroup;
  }

  bool _isExtraCandidate(int place) {
    return qualificationPlan.extraCount > 0 &&
        place == qualificationPlan.extraRank &&
        qualificationPlan.extraGroups.contains(groupNumber);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 178,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            groupLabel(groupNumber),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var place = 1; place <= playerCount; place++)
                _QualificationPlaceBadge(
                  place: place,
                  isQualified: place <= _fixedForGroup,
                  isExtraCandidate: _isExtraCandidate(place),
                  onTap: () => onCyclePlace(groupNumber, place),
                ),
            ],
          ),
          if (_isEliminationGroupPlayType(playType) && playerCount >= 2) ...[
            const SizedBox(height: 10),
            _MiniKnockoutQualificationPreview(
              groupNumber: groupNumber,
              playerCount: playerCount,
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniKnockoutQualificationPreview extends StatelessWidget {
  const _MiniKnockoutQualificationPreview({
    required this.groupNumber,
    required this.playerCount,
  });

  final int groupNumber;
  final int playerCount;

  @override
  Widget build(BuildContext context) {
    final labels = [
      for (var index = 0; index < playerCount; index++)
        '${groupLabel(groupNumber)} Platz ${index + 1}',
    ];
    final bracketSize = _nextPowerOfTwo(playerCount);
    final slots = [
      for (final seed in _seedOrderForSize(bracketSize))
        seed <= playerCount ? seed : null,
    ];

    return SizedBox(
      height: 190,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: _CompactKnockoutPreviewTree(
          bracketSize: bracketSize,
          slotOrder: slots,
          participantLabels: labels,
          onSwapSlot: (_, _) {},
        ),
      ),
    );
  }
}

class _QualificationPlaceBadge extends StatelessWidget {
  const _QualificationPlaceBadge({
    required this.place,
    required this.isQualified,
    required this.isExtraCandidate,
    required this.onTap,
  });

  final int place;
  final bool isQualified;
  final bool isExtraCandidate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isQualified
        ? const Color(0xFFC8F7DC)
        : isExtraCandidate
        ? const Color(0xFFFFE8A3)
        : colorScheme.surfaceContainerHighest;
    final borderColor = isQualified
        ? const Color(0xFF14965F)
        : isExtraCandidate
        ? const Color(0xFFC58A00)
        : colorScheme.outlineVariant;

    return Tooltip(
      message: isQualified
          ? 'Sicher weiter'
          : isExtraCandidate
          ? 'Vergleich um Zusatzplatz'
          : 'Scheidet aus',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('$place.'),
        ),
      ),
    );
  }
}

class _InheritedKnockoutSetup extends StatelessWidget {
  const _InheritedKnockoutSetup({
    required this.previousStage,
    required this.qualificationPlan,
    required this.participantCount,
    required this.bracketSize,
    required this.byeCount,
    required this.eliminationLossLimit,
    required this.seedingMode,
    required this.slotOrder,
    required this.participantLabels,
    required this.onSeedingModeChanged,
    required this.onSwapSlot,
    required this.onResetSlots,
  });

  final TournamentStage? previousStage;
  final QualificationPlan? qualificationPlan;
  final int? participantCount;
  final int? bracketSize;
  final int byeCount;
  final int eliminationLossLimit;
  final String seedingMode;
  final List<int?> slotOrder;
  final List<String> participantLabels;
  final ValueChanged<String> onSeedingModeChanged;
  final void Function(int fromIndex, int toIndex) onSwapSlot;
  final VoidCallback onResetSlots;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          previousStage == null
              ? 'Start mit allen Spielern'
              : 'Uebernahme aus vorheriger Etappe',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (previousStage == null)
          const Text('Alle angelegten Spieler nehmen teil.')
        else if (qualificationPlan != null)
          _QualificationRuleSummary(qualificationPlan: qualificationPlan)
        else
          Text(
            previousStage!.qualificationSummary ?? 'Alle Teilnehmer weiter.',
          ),
        const SizedBox(height: 8),
        _KnockoutPreview(
          participantCount: participantCount,
          bracketSize: bracketSize,
          byeCount: byeCount,
          eliminationLossLimit: eliminationLossLimit,
          seedingMode: seedingMode,
          slotOrder: slotOrder,
          participantLabels: participantLabels,
          onSeedingModeChanged: onSeedingModeChanged,
          onSwapSlot: onSwapSlot,
          onResetSlots: onResetSlots,
        ),
      ],
    );
  }
}

class _QualificationRuleSummary extends StatelessWidget {
  const _QualificationRuleSummary({required this.qualificationPlan});

  final QualificationPlan? qualificationPlan;

  @override
  Widget build(BuildContext context) {
    final plan = qualificationPlan;
    if (plan == null) {
      return const Text('Keine gueltige Anzahl Weiterkommende.');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(label: Text('${plan.totalQualifiers} Weiterkommende')),
        if (plan.fixedByGroup.isNotEmpty &&
            plan.fixedByGroup.toSet().length > 1)
          Chip(label: Text(_fixedByGroupSummary(plan.fixedByGroup)))
        else if (plan.fixedPerGroup > 0)
          Chip(label: Text('Top ${plan.fixedPerGroup} je Gruppe')),
        if (plan.extraCount > 0)
          Chip(
            label: Text(
              'Beste ${plan.extraCount} der ${plan.extraRank}. Plaetze',
            ),
          ),
        if (plan.extraCount > 0 && plan.extraGroups.isNotEmpty)
          Chip(label: Text('Zusatz aus ${_formatGroups(plan.extraGroups)}')),
      ],
    );
  }

  String _formatGroups(List<int> groups) {
    if (groups.length == 1) {
      return groupLabel(groups.first);
    }

    return groups.map(groupLabel).join(', ');
  }

  String _fixedByGroupSummary(List<int> fixedByGroup) {
    return [
      for (var index = 0; index < fixedByGroup.length; index++)
        '${groupLabel(index + 1)} ${fixedByGroup[index]}',
    ].join(', ');
  }
}

class _StageList extends StatelessWidget {
  const _StageList({
    required this.stages,
    required this.editingStageIndex,
    required this.onEditStage,
    required this.onRemoveStage,
  });

  final List<TournamentStage> stages;
  final int? editingStageIndex;
  final void Function(int index) onEditStage;
  final void Function(int index) onRemoveStage;

  String _typeLabel(String type) {
    return switch (type) {
      'single_knockout' => 'K.-o.-Runde',
      'double_knockout' => 'Doppel-K.-o.',
      'triple_knockout' => 'Triple-K.-o.',
      _ => 'Gruppen/Liga',
    };
  }

  String _repeatDetails(TournamentStage stage) {
    if (stage.groupRoundRobinRepeats.isEmpty) {
      return '';
    }

    final details = [
      for (var index = 0; index < stage.groupSizes.length; index++)
        if (_groupPlayTypeForStage(stage, index) == 'round_robin')
          '${groupLabel(index + 1)} ${index < stage.groupRoundRobinRepeats.length ? stage.groupRoundRobinRepeats[index] : 1}x',
    ].join(', ');

    return details.isEmpty ? '' : ' - Begegnungen: $details';
  }

  int _stageMatchCount(TournamentStage stage) {
    if (_isKnockoutStageType(stage.type)) {
      return _eliminationMatchEstimate(
        stage.knockoutParticipantCount ?? 0,
        _lossLimitForStageType(stage.type),
      );
    }

    var totalMatches = 0;
    for (var index = 0; index < stage.groupSizes.length; index++) {
      final repeatCount = _roundRobinRepeatForStage(stage, index);
      final playType = _groupPlayTypeForStage(stage, index);
      totalMatches += playType == 'round_robin'
          ? _roundRobinMatchCount(stage.groupSizes[index], repeatCount)
          : _eliminationMatchEstimate(
              stage.groupSizes[index],
              _lossLimitForGroupPlayType(playType),
            );
    }

    return totalMatches;
  }

  String _matchCountDetails(TournamentStage stage) {
    return ' - ${_stageMatchCount(stage)} Spiele';
  }

  String _stageDetails(TournamentStage stage) {
    if (stage.type != 'groups' || stage.groupSizes.isEmpty) {
      if (_isKnockoutStageType(stage.type) &&
          stage.knockoutParticipantCount != null &&
          stage.knockoutBracketSize != null) {
        final qualifierText = stage.qualificationSummary == null
            ? ''
            : ' - ${stage.qualificationSummary}';
        final seedingText = stage.knockoutSeedingMode == 'random'
            ? ' - Zufall'
            : ' - Cross seeded';

        return '${_typeLabel(stage.type)} - '
            '${stage.knockoutParticipantCount} Teilnehmer, '
            '${stage.knockoutBracketSize}er Feld, '
            '${stage.knockoutByeCount} Freilose'
            '${_lossLimitForStageType(stage.type) > 1 ? ' - Aus nach ${_lossLimitForStageType(stage.type)} Niederlage(n)' : ''}'
            '$seedingText'
            '${_matchCountDetails(stage)}'
            '$qualifierText';
      }

      return _typeLabel(stage.type);
    }

    final sizes = stage.groupSizes
        .asMap()
        .entries
        .map((entry) => '${groupLabel(entry.key + 1)}: ${entry.value}')
        .join(', ');

    final qualifierText = stage.qualificationSummary == null
        ? ''
        : ' - ${stage.qualificationSummary}';
    final playTypeText = ' - Spieltypen: ${stage.groupSizes.asMap().entries.map((entry) {
      return '${groupLabel(entry.key + 1)} ${_groupPlayTypeLabel(_groupPlayTypeForStage(stage, entry.key))}';
    }).join(', ')}';
    final repeatText = _repeatDetails(stage);
    final tieBreakerText =
        ' - Tie-Breaker: ${stage.groupTieBreakers.map(tieBreakerLabel).join(', ')}';

    return '${_typeLabel(stage.type)} - $sizes$playTypeText$repeatText${_matchCountDetails(stage)}$qualifierText$tieBreakerText';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (stages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('Noch keine Etappen hinzugefuegt.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${stages.length} Etappen im Turnier',
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < stages.length; index++)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: editingStageIndex == index
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: ListTile(
              dense: true,
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(stages[index].name),
              subtitle: Text(_stageDetails(stages[index])),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    onPressed: () => onEditStage(index),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Etappe bearbeiten',
                  ),
                  IconButton(
                    onPressed: () => onRemoveStage(index),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Etappe entfernen',
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
