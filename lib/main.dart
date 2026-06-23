import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
part 'tournament_models.dart';
part 'tournament_storage.dart';


const List<String> defaultGroupTieBreakers = [
  'points',
  'legDifference',
  'legsFor',
  'headToHead',
];

String tieBreakerLabel(String tieBreaker) {
  return switch (tieBreaker) {
    'points' => 'Punkte',
    'legDifference' => 'Leg-Differenz',
    'legsFor' => 'Gewonnene Legs',
    'headToHead' => 'Direkter Vergleich',
    _ => tieBreaker,
  };
}

String groupLabel(int groupNumber) {
  var number = groupNumber;
  var label = '';
  while (number > 0) {
    number--;
    label = String.fromCharCode(65 + (number % 26)) + label;
    number ~/= 26;
  }

  return 'Gruppe $label';
}

int _roundRobinRepeatForStage(TournamentStage stage, int groupIndex) {
  if (groupIndex < 0 || groupIndex >= stage.groupRoundRobinRepeats.length) {
    return 1;
  }

  final repeatCount = stage.groupRoundRobinRepeats[groupIndex];
  return repeatCount < 1 ? 1 : repeatCount;
}

String _groupPlayTypeForStage(TournamentStage stage, int groupIndex) {
  if (groupIndex >= 0 && groupIndex < stage.groupPlayTypes.length) {
    return stage.groupPlayTypes[groupIndex];
  }

  return stage.groupPlayType;
}

String _groupPlayTypeLabel(String playType) {
  return switch (playType) {
    'round_robin' => 'Jeder gegen jeden',
    'mini_knockout' => 'Mini-KO in der Gruppe',
    _ => playType,
  };
}

List<GroupMatch> _buildRoundRobinMatches(
  List<TournamentPlayer> players, {
  int repeatCount = 1,
}) {
  final matches = <GroupMatch>[];
  if (players.length < 2) {
    return matches;
  }

  final playerCount = players.length.isOdd
      ? players.length + 1
      : players.length;
  final rounds = playerCount - 1;
  final matchesPerRound = playerCount ~/ 2;
  final safeRepeatCount = repeatCount < 1 ? 1 : repeatCount;

  for (var repeat = 0; repeat < safeRepeatCount; repeat++) {
    final rotation = List<TournamentPlayer?>.from(players);
    if (rotation.length.isOdd) {
      rotation.add(null);
    }

    for (var round = 0; round < rounds; round++) {
      for (var pairIndex = 0; pairIndex < matchesPerRound; pairIndex++) {
        final firstPlayer = rotation[pairIndex];
        final secondPlayer = rotation[playerCount - 1 - pairIndex];
        if (firstPlayer == null || secondPlayer == null) {
          continue;
        }

        final swapHome = repeat.isOdd;
        final homePlayer = swapHome ? secondPlayer : firstPlayer;
        final awayPlayer = swapHome ? firstPlayer : secondPlayer;

        matches.add(
          GroupMatch(
            homePlayer: homePlayer,
            awayPlayer: awayPlayer,
            round: repeat * rounds + round + 1,
          ),
        );
      }

      final fixedPlayer = rotation.first;
      final rotatingPlayers = rotation.sublist(1);
      rotatingPlayers.insert(0, rotatingPlayers.removeLast());
      rotation
        ..clear()
        ..add(fixedPlayer)
        ..addAll(rotatingPlayers);
    }
  }

  return matches;
}

int _roundRobinMatchCount(int groupSize, int repeatCount) {
  if (groupSize < 2) {
    return 0;
  }

  final safeRepeatCount = repeatCount < 1 ? 1 : repeatCount;
  return (groupSize * (groupSize - 1) ~/ 2) * safeRepeatCount;
}

int _knockoutPlayableMatchCount(int participantCount) {
  return participantCount < 2 ? 0 : participantCount - 1;
}

int _nextPowerOfTwo(int value) {
  var size = 2;
  while (size < value) {
    size *= 2;
  }
  return size;
}

List<int> _seedOrderForSize(int bracketSize) {
  var order = <int>[1, 2];
  var size = 2;
  while (size < bracketSize) {
    final nextSize = size * 2;
    order = [
      for (final seed in order) ...[seed, nextSize + 1 - seed],
    ];
    size = nextSize;
  }

  return order;
}

class _KnockoutSeedSource {
  const _KnockoutSeedSource({
    required this.seed,
    required this.groupNumber,
    required this.place,
  });

  final int seed;
  final int? groupNumber;
  final int place;
}

void main() {
  runApp(const DartTournamentApp());
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _storage = TournamentStorage();
  late Future<List<CreatedTournament>> _tournamentsFuture;

  @override
  void initState() {
    super.initState();
    _tournamentsFuture = _storage.loadTournaments();
  }

  void _reloadTournaments() {
    setState(() {
      _tournamentsFuture = _storage.loadTournaments();
    });
  }

  Future<void> _openCreationPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TournamentCreationPage()),
    );
    _reloadTournaments();
  }

  Future<void> _openTournament(CreatedTournament tournament) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TournamentRunPage(tournament: tournament),
      ),
    );
    _reloadTournaments();
  }

  Future<void> _deleteTournament(CreatedTournament tournament) async {
    await _storage.deleteTournament(tournament.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${tournament.name} geloescht.')),
    );
    _reloadTournaments();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dart Turnierverwaltung'),
        backgroundColor: colorScheme.primaryContainer,
      ),
      body: SafeArea(
        child: FutureBuilder<List<CreatedTournament>>(
          future: _tournamentsFuture,
          builder: (context, snapshot) {
            final tournaments = snapshot.data ?? const <CreatedTournament>[];

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Icon(Icons.sports_score, size: 64, color: colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Meine Turniere',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gespeicherte Turniere fortsetzen oder ein neues Turnier anlegen.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _openCreationPage,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Turnier erstellen'),
                ),
                const SizedBox(height: 32),
                Text(
                  'Gespeicherte Turniere',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (tournaments.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Noch keine Turniere gespeichert.'),
                    ),
                  )
                else
                  for (final tournament in tournaments)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.emoji_events_outlined),
                        title: Text(tournament.name),
                        subtitle: Text(
                          '${tournament.players.length} Spieler - '
                          '${tournament.stages.length} Etappen',
                        ),
                        trailing: IconButton(
                          onPressed: () => _deleteTournament(tournament),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Turnier loeschen',
                        ),
                        onTap: () => _openTournament(tournament),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class TournamentCreationPage extends StatefulWidget {
  const TournamentCreationPage({super.key});

  @override
  State<TournamentCreationPage> createState() => _TournamentCreationPageState();
}

class _TournamentCreationPageState extends State<TournamentCreationPage> {
  final _tournamentNameController = TextEditingController();
  final _playerNameController = TextEditingController();
  final _playerCountController = TextEditingController(text: '8');
  final _stageNameController = TextEditingController();
  final _groupCountController = TextEditingController(text: '2');
  final _groupQualifierCountController = TextEditingController(text: '8');
  final _bestOfQualifierCountController = TextEditingController(text: '0');
  final Set<int> _selectedExtraGroups = {};
  final List<TournamentPlayer> _players = [];
  final List<TournamentStage> _stages = [];
  final List<String> _groupTieBreakers = List<String>.from(
    defaultGroupTieBreakers,
  );
  final List<int> _groupRoundRobinRepeats = [];
  final List<String> _groupPlayTypes = [];
  final List<int> _fixedQualifiersByGroup = [];
  int? _manualExtraRank;
  int? _manualExtraCount;
  bool _autoAdjustQualification = true;
  int? _editingStageIndex;
  String _groupPlayType = 'round_robin';
  List<int?>? _manualKnockoutSlotOrder;
  String _selectedStageType = 'groups';
  String _knockoutSeedingMode = 'cross';
  bool _stageNameWasEdited = false;

  @override
  void initState() {
    super.initState();
    _stageNameController.text = _defaultStageName();
  }

  @override
  void dispose() {
    _tournamentNameController.dispose();
    _playerNameController.dispose();
    _playerCountController.dispose();
    _stageNameController.dispose();
    _groupCountController.dispose();
    _groupQualifierCountController.dispose();
    _bestOfQualifierCountController.dispose();
    super.dispose();
  }

  List<int> _calculateGroupSizes() {
    final groupCount = int.tryParse(_groupCountController.text);
    if (groupCount == null || groupCount < 1 || _players.isEmpty) {
      return const [];
    }

    final cappedGroupCount = groupCount > _players.length
        ? _players.length
        : groupCount;
    final baseSize = _players.length ~/ cappedGroupCount;
    final remainder = _players.length % cappedGroupCount;

    return List.generate(
      cappedGroupCount,
      (index) => baseSize + (index < remainder ? 1 : 0),
    );
  }

  List<int> _roundRobinRepeatsForGroupSizes(List<int> groupSizes) {
    return [
      for (var index = 0; index < groupSizes.length; index++)
        index < _groupRoundRobinRepeats.length
            ? _groupRoundRobinRepeats[index]
            : 1,
    ];
  }

  List<String> _playTypesForGroupSizes(List<int> groupSizes) {
    return [
      for (var index = 0; index < groupSizes.length; index++)
        index < _groupPlayTypes.length
            ? _groupPlayTypes[index]
            : _groupPlayType,
    ];
  }

  void _setDefaultGroupPlayType(String playType) {
    final groupSizes = _calculateGroupSizes();
    setState(() {
      _groupPlayType = playType;
      _groupPlayTypes
        ..clear()
        ..addAll(List.filled(groupSizes.length, playType));
    });
  }

  void _setGroupPlayType(int groupIndex, String playType) {
    final groupSizes = _calculateGroupSizes();
    if (groupIndex < 0 || groupIndex >= groupSizes.length) {
      return;
    }

    setState(() {
      while (_groupPlayTypes.length < groupSizes.length) {
        _groupPlayTypes.add(_groupPlayType);
      }
      _groupPlayTypes[groupIndex] = playType;
    });
  }

  void _changeGroupRoundRobinRepeats(int groupIndex, int delta) {
    final groupSizes = _calculateGroupSizes();
    if (groupIndex < 0 || groupIndex >= groupSizes.length) {
      return;
    }

    setState(() {
      while (_groupRoundRobinRepeats.length < groupSizes.length) {
        _groupRoundRobinRepeats.add(1);
      }
      final nextValue = _groupRoundRobinRepeats[groupIndex] + delta;
      _groupRoundRobinRepeats[groupIndex] = nextValue < 1 ? 1 : nextValue;
    });
  }

  int _currentStageMatchCount() {
    if (_selectedStageType == 'single_knockout') {
      return _knockoutPlayableMatchCount(_knockoutParticipantCount() ?? 0);
    }

    final groupSizes = _calculateGroupSizes();
    final repeats = _roundRobinRepeatsForGroupSizes(groupSizes);
    final playTypes = _playTypesForGroupSizes(groupSizes);
    var totalMatches = 0;
    for (var index = 0; index < groupSizes.length; index++) {
      totalMatches += playTypes[index] == 'mini_knockout'
          ? _knockoutPlayableMatchCount(groupSizes[index])
          : _roundRobinMatchCount(groupSizes[index], repeats[index]);
    }

    return totalMatches;
  }

  List<String> _currentStageMatchDetails() {
    if (_selectedStageType == 'single_knockout') {
      final participants = _knockoutParticipantCount() ?? 0;
      return [
        '$participants Teilnehmer',
        '${_knockoutByeCount()} Freilose',
      ];
    }

    final groupSizes = _calculateGroupSizes();
    final repeats = _roundRobinRepeatsForGroupSizes(groupSizes);
    final playTypes = _playTypesForGroupSizes(groupSizes);
    return [
      for (var index = 0; index < groupSizes.length; index++)
        playTypes[index] == 'mini_knockout'
            ? '${groupLabel(index + 1)} ${_knockoutPlayableMatchCount(groupSizes[index])}'
            : '${groupLabel(index + 1)} ${_roundRobinMatchCount(groupSizes[index], repeats[index])}',
    ];
  }

  int? _groupQualifierCount() {
    final participantCount = int.tryParse(_groupQualifierCountController.text);
    if (participantCount == null || participantCount < 2) {
      return null;
    }

    return participantCount;
  }

  int? _inheritedParticipantCount() {
    final previousStage = _previousStageForCurrentForm();
    if (previousStage == null) {
      return _players.length;
    }

    return previousStage.qualifiedParticipantCount ??
        previousStage.knockoutParticipantCount ??
        _players.length;
  }

  int? _knockoutParticipantCount() {
    final participantCount = _inheritedParticipantCount();
    if (participantCount == null || participantCount < 2) {
      return null;
    }

    return participantCount;
  }

  int? _knockoutBracketSize() {
    final participantCount = _knockoutParticipantCount();
    if (participantCount == null) {
      return null;
    }

    var bracketSize = 2;
    while (bracketSize < participantCount) {
      bracketSize *= 2;
    }

    return bracketSize;
  }

  int _knockoutByeCount() {
    final participantCount = _knockoutParticipantCount();
    final bracketSize = _knockoutBracketSize();
    if (participantCount == null || bracketSize == null) {
      return 0;
    }

    return bracketSize - participantCount;
  }

  List<int?> _automaticKnockoutSlotOrder(
    int participantCount,
    int bracketSize,
  ) {
    if (_knockoutSeedingMode == 'random') {
      return _randomKnockoutSlotOrder(participantCount, bracketSize);
    }

    return _crossSeededKnockoutSlotOrder(participantCount, bracketSize);
  }

  List<int?> _randomKnockoutSlotOrder(int participantCount, int bracketSize) {
    final shuffledSeeds = <int>[
      for (var seed = 1; seed <= participantCount; seed++) seed,
    ]..shuffle(Random());

    var seedIndex = 0;
    return [
      for (final bracketSeed in _seedOrderForSize(bracketSize))
        bracketSeed <= participantCount ? shuffledSeeds[seedIndex++] : null,
    ];
  }

  List<int?> _crossSeededKnockoutSlotOrder(
    int participantCount,
    int bracketSize,
  ) {
    final seedSources = _knockoutSeedSources(participantCount);
    final strengthOrderedSources = List<_KnockoutSeedSource>.from(seedSources)
      ..sort(_compareKnockoutSeedStrength);

    final byeCount = bracketSize - participantCount;
    final pairs = <List<_KnockoutSeedSource?>>[];
    final remaining = List<_KnockoutSeedSource>.from(strengthOrderedSources);

    for (var index = 0; index < byeCount && remaining.isNotEmpty; index++) {
      pairs.add([remaining.removeAt(0), null]);
    }

    while (remaining.isNotEmpty) {
      final stronger = remaining.removeAt(0);
      var opponentIndex = remaining.lastIndexWhere((candidate) {
        return !_sameKnownGroup(stronger, candidate);
      });
      if (opponentIndex == -1) {
        opponentIndex = remaining.length - 1;
      }
      final weaker = remaining.removeAt(opponentIndex);
      pairs.add([stronger, weaker]);
    }

    final slots = <int?>[
      for (final pair in pairs) ...[
        pair[0]?.seed,
        pair.length > 1 ? pair[1]?.seed : null,
      ],
    ];

    while (slots.length < bracketSize) {
      slots.add(null);
    }
    return slots;
  }

  List<int> _defaultFixedQualifiersForPlan(
    List<int> groupSizes,
    QualificationPlan? plan,
  ) {
    if (plan == null) {
      return List.filled(groupSizes.length, 0);
    }

    return [
      for (final groupSize in groupSizes)
        plan.fixedPerGroup > groupSize ? groupSize : plan.fixedPerGroup,
    ];
  }

  List<int> _currentFixedQualifiersByGroup(
    List<int> groupSizes,
    QualificationPlan? fallbackPlan,
  ) {
    if (_fixedQualifiersByGroup.length == groupSizes.length) {
      return [
        for (var index = 0; index < groupSizes.length; index++)
          _fixedQualifiersByGroup[index].clamp(0, groupSizes[index]).toInt(),
      ];
    }

    return _defaultFixedQualifiersForPlan(groupSizes, fallbackPlan);
  }

  int _compareKnockoutSeedStrength(
    _KnockoutSeedSource a,
    _KnockoutSeedSource b,
  ) {
    final placeCompare = a.place.compareTo(b.place);
    if (placeCompare != 0) {
      return placeCompare;
    }
    final groupCompare = (a.groupNumber ?? 999).compareTo(
      b.groupNumber ?? 999,
    );
    if (groupCompare != 0) {
      return groupCompare;
    }
    return a.seed.compareTo(b.seed);
  }

  bool _sameKnownGroup(_KnockoutSeedSource a, _KnockoutSeedSource b) {
    return a.groupNumber != null && a.groupNumber == b.groupNumber;
  }

  List<_KnockoutSeedSource> _knockoutSeedSources(int participantCount) {
    final previousStage = _previousStageForCurrentForm();
    final groupPlan = _storedGroupQualificationPlan(previousStage);
    if (previousStage == null ||
        previousStage.type != 'groups' ||
        previousStage.groupSizes.isEmpty) {
      return [
        for (var seed = 1; seed <= participantCount; seed++)
          _KnockoutSeedSource(seed: seed, groupNumber: null, place: seed),
      ];
    }

    final sources = <_KnockoutSeedSource>[];
    var seed = 1;
    if (groupPlan == null) {
      for (
        var groupIndex = 0;
        groupIndex < previousStage.groupSizes.length;
        groupIndex++
      ) {
        for (
          var place = 1;
          place <= previousStage.groupSizes[groupIndex];
          place++
        ) {
          sources.add(
            _KnockoutSeedSource(
              seed: seed,
              groupNumber: groupIndex + 1,
              place: place,
            ),
          );
          seed++;
        }
      }
    } else {
      for (
        var groupIndex = 0;
        groupIndex < previousStage.groupSizes.length;
        groupIndex++
      ) {
        final fixedForGroup = groupIndex < groupPlan.fixedByGroup.length
            ? groupPlan.fixedByGroup[groupIndex]
            : groupPlan.fixedPerGroup;
        for (var place = 1; place <= fixedForGroup; place++) {
          sources.add(
            _KnockoutSeedSource(
              seed: seed,
              groupNumber: groupIndex + 1,
              place: place,
            ),
          );
          seed++;
        }
      }
      for (final groupNumber in groupPlan.extraGroups) {
        sources.add(
          _KnockoutSeedSource(
            seed: seed,
            groupNumber: groupNumber,
            place: groupPlan.extraRank,
          ),
        );
        seed++;
      }
    }

    while (sources.length < participantCount) {
      sources.add(
        _KnockoutSeedSource(
          seed: sources.length + 1,
          groupNumber: null,
          place: sources.length + 1,
        ),
      );
    }

    return sources.take(participantCount).toList();
  }

  bool _isValidKnockoutSlotOrder(
    List<int?> slotOrder,
    int participantCount,
    int bracketSize,
  ) {
    if (slotOrder.length != bracketSize) {
      return false;
    }

    final values = slotOrder.whereType<int>().toList()..sort();
    if (values.length != participantCount) {
      return false;
    }

    for (var index = 0; index < values.length; index++) {
      if (values[index] != index + 1) {
        return false;
      }
    }

    return true;
  }

  bool _slotOrderGivesBestSeedsByes(
    List<int?> slotOrder,
    int participantCount,
    int bracketSize,
  ) {
    final byeCount = bracketSize - participantCount;
    if (byeCount <= 0) {
      return true;
    }

    final expectedByeSeeds = _strongestByeSeeds(participantCount, byeCount);
    final actualByeSeeds = <int>{};
    for (var index = 0; index < slotOrder.length; index += 2) {
      final first = slotOrder[index];
      final second = index + 1 < slotOrder.length ? slotOrder[index + 1] : null;
      if (first == null && second != null) {
        actualByeSeeds.add(second);
      } else if (second == null && first != null) {
        actualByeSeeds.add(first);
      }
    }

    return actualByeSeeds.length == expectedByeSeeds.length &&
        actualByeSeeds.containsAll(expectedByeSeeds);
  }

  Set<int> _strongestByeSeeds(int participantCount, int byeCount) {
    final seedSources = _knockoutSeedSources(participantCount);
    seedSources.sort((a, b) {
      final placeCompare = a.place.compareTo(b.place);
      if (placeCompare != 0) {
        return placeCompare;
      }
      final groupCompare = (a.groupNumber ?? 999).compareTo(
        b.groupNumber ?? 999,
      );
      if (groupCompare != 0) {
        return groupCompare;
      }
      return a.seed.compareTo(b.seed);
    });

    return seedSources.take(byeCount).map((source) => source.seed).toSet();
  }

  List<int?> _knockoutSlotOrder() {
    final participantCount = _knockoutParticipantCount();
    final bracketSize = _knockoutBracketSize();
    if (participantCount == null || bracketSize == null) {
      return const [];
    }

    final manualOrder = _manualKnockoutSlotOrder;
    if (manualOrder != null &&
        _isValidKnockoutSlotOrder(manualOrder, participantCount, bracketSize) &&
        _slotOrderAvoidsByePair(manualOrder) &&
        (_knockoutSeedingMode != 'cross' ||
            _slotOrderGivesBestSeedsByes(
              manualOrder,
              participantCount,
              bracketSize,
            ))) {
      return List<int?>.from(manualOrder);
    }

    return _automaticKnockoutSlotOrder(participantCount, bracketSize);
  }

  bool _slotOrderAvoidsByePair(List<int?> slotOrder) {
    for (var index = 0; index < slotOrder.length; index += 2) {
      final first = slotOrder[index];
      final second = index + 1 < slotOrder.length ? slotOrder[index + 1] : null;
      if (first == null && second == null) {
        return false;
      }
    }
    return true;
  }

  List<String> _knockoutParticipantLabels() {
    final participantCount = _knockoutParticipantCount();
    if (participantCount == null) {
      return const [];
    }

    final previousStage = _previousStageForCurrentForm();
    final groupPlan = _storedGroupQualificationPlan(previousStage);
    if (previousStage == null ||
        previousStage.type != 'groups' ||
        previousStage.groupSizes.isEmpty) {
      return [
        for (var index = 0; index < participantCount; index++)
          'Platz ${index + 1}',
      ];
    }

    final labels = <String>[];
    if (groupPlan == null) {
      for (
        var groupIndex = 0;
        groupIndex < previousStage.groupSizes.length;
        groupIndex++
      ) {
        for (
          var place = 1;
          place <= previousStage.groupSizes[groupIndex];
          place++
        ) {
          labels.add('$place. ${groupLabel(groupIndex + 1)}');
        }
      }
    } else {
      for (
        var groupIndex = 0;
        groupIndex < previousStage.groupSizes.length;
        groupIndex++
      ) {
        final fixedForGroup = groupIndex < groupPlan.fixedByGroup.length
            ? groupPlan.fixedByGroup[groupIndex]
            : groupPlan.fixedPerGroup;
        for (var place = 1; place <= fixedForGroup; place++) {
          labels.add('$place. ${groupLabel(groupIndex + 1)}');
        }
      }
      for (final groupNumber in groupPlan.extraGroups) {
        labels.add('${groupPlan.extraRank}. ${groupLabel(groupNumber)}');
      }
    }

    while (labels.length < participantCount) {
      labels.add('Platz ${labels.length + 1}');
    }

    return labels.take(participantCount).toList();
  }

  void _swapKnockoutSlots(int fromIndex, int toIndex) {
    final slots = _knockoutSlotOrder();
    if (fromIndex < 0 ||
        toIndex < 0 ||
        fromIndex >= slots.length ||
        toIndex >= slots.length) {
      return;
    }

    setState(() {
      final moved = slots[fromIndex];
      slots[fromIndex] = slots[toIndex];
      slots[toIndex] = moved;
      _manualKnockoutSlotOrder = slots;
    });
  }

  void _resetKnockoutSlots() {
    setState(() {
      if (_knockoutSeedingMode == 'random') {
        final participantCount = _knockoutParticipantCount();
        final bracketSize = _knockoutBracketSize();
        _manualKnockoutSlotOrder =
            participantCount == null || bracketSize == null
            ? null
            : _randomKnockoutSlotOrder(participantCount, bracketSize);
      } else {
        _manualKnockoutSlotOrder = null;
      }
    });
  }

  void _setKnockoutSeedingMode(String mode) {
    setState(() {
      _knockoutSeedingMode = mode;
      if (mode == 'random') {
        final participantCount = _knockoutParticipantCount();
        final bracketSize = _knockoutBracketSize();
        _manualKnockoutSlotOrder =
            participantCount == null || bracketSize == null
            ? null
            : _randomKnockoutSlotOrder(participantCount, bracketSize);
      } else {
        _manualKnockoutSlotOrder = null;
      }
    });
  }

  TournamentStage? _latestGroupStage() {
    final endIndex = _editingStageIndex ?? _stages.length;
    for (var index = endIndex - 1; index >= 0; index--) {
      final stage = _stages[index];
      if (stage.type == 'groups' && stage.groupSizes.isNotEmpty) {
        return stage;
      }
    }

    return null;
  }

  TournamentStage? _previousStageForCurrentForm() {
    final editingIndex = _editingStageIndex;
    if (editingIndex != null) {
      return editingIndex == 0 ? null : _stages[editingIndex - 1];
    }

    return _stages.isEmpty ? null : _stages.last;
  }

  String _stageTypeLabel(String type) {
    return switch (type) {
      'single_knockout' => 'K.-o.-Runde',
      _ => 'Gruppenphase',
    };
  }

  String _defaultStageName([String? stageType]) {
    final type = stageType ?? _selectedStageType;
    final baseName = _stageTypeLabel(type);
    final sameTypeCount = _stages.where((stage) => stage.type == type).length;
    return sameTypeCount == 0 ? baseName : '$baseName ${sameTypeCount + 1}';
  }

  void _setDefaultStageNameIfNeeded([String? stageType]) {
    if (_stageNameWasEdited && _stageNameController.text.trim().isNotEmpty) {
      return;
    }

    _stageNameController.text = _defaultStageName(stageType);
    _stageNameController.selection = TextSelection.collapsed(
      offset: _stageNameController.text.length,
    );
  }

  QualificationPlan? _qualificationPlanForGroupSizes(
    List<int> groupSizes,
    int? participantCount,
  ) {
    if (participantCount == null) {
      return null;
    }

    final groupCount = groupSizes.length;
    if (groupCount == 0) {
      return null;
    }

    final maxQualifiers = groupSizes.fold<int>(0, (sum, size) => sum + size);
    final cappedParticipantCount = participantCount > maxQualifiers
        ? maxQualifiers
        : participantCount;
    final fixedPerGroup = cappedParticipantCount ~/ groupCount;
    final automaticExtraCount = cappedParticipantCount % groupCount;
    final hasManualFixed = _fixedQualifiersByGroup.length == groupSizes.length;
    final fixedByGroup = hasManualFixed
        ? _currentFixedQualifiersByGroup(groupSizes, null)
        : [
            for (final groupSize in groupSizes)
              fixedPerGroup > groupSize ? groupSize : fixedPerGroup,
          ];
    final fixedTotal = fixedByGroup.fold<int>(0, (sum, value) => sum + value);
    final extraCount = !_autoAdjustQualification && hasManualFixed
        ? (_manualExtraCount ?? 0).clamp(0, groupCount).toInt()
        : hasManualFixed
        ? (cappedParticipantCount - fixedTotal).clamp(0, groupCount).toInt()
        : automaticExtraCount;
    final extraRank = hasManualFixed
        ? (_manualExtraRank ?? fixedPerGroup + 1)
        : fixedPerGroup + 1;
    final eligibleGroupSize = extraCount == 0
        ? null
        : groupSizes
              .where((size) => size >= extraRank)
              .fold<int>(0, (largest, size) => size > largest ? size : largest);
    final eligibleGroups = extraCount == 0
        ? const <int>[]
        : [
            for (var index = 0; index < groupSizes.length; index++)
              if (groupSizes[index] >= extraRank) index + 1,
          ];
    final automaticExtraGroups = eligibleGroupSize == null
        ? const <int>[]
        : [
            for (var index = 0; index < groupSizes.length; index++)
              if (groupSizes[index] == eligibleGroupSize) index + 1,
          ];
    final manualExtraGroups =
        _selectedExtraGroups
            .where((groupNumber) => eligibleGroups.contains(groupNumber))
            .toList()
          ..sort();
    final extraGroups = manualExtraGroups.isNotEmpty || !_autoAdjustQualification
        ? manualExtraGroups
        : automaticExtraGroups;

    return QualificationPlan(
      totalQualifiers: cappedParticipantCount,
      fixedPerGroup: fixedPerGroup,
      extraCount: extraCount,
      extraRank: extraRank,
      eligibleGroupSize: eligibleGroupSize,
      extraGroups: extraGroups,
      fixedByGroup: fixedByGroup,
    );
  }

  QualificationPlan? _groupQualificationPlan() {
    return _qualificationPlanForGroupSizes(
      _calculateGroupSizes(),
      _groupQualifierCount(),
    );
  }

  QualificationPlan? _storedGroupQualificationPlan(TournamentStage? stage) {
    if (stage == null || stage.groupSizes.isEmpty) {
      return null;
    }

    final participantCount = stage.qualifiedParticipantCount;
    if (participantCount == null) {
      return null;
    }

    final groupCount = stage.groupSizes.length;
    final maxQualifiers = stage.groupSizes.fold<int>(
      0,
      (sum, size) => sum + size,
    );
    final cappedParticipantCount = participantCount > maxQualifiers
        ? maxQualifiers
        : participantCount;
    final fixedPerGroup = cappedParticipantCount ~/ groupCount;
    final storedFixedByGroup = stage.fixedQualifiersByGroup.length == groupCount
        ? [
            for (var index = 0; index < groupCount; index++)
              stage.fixedQualifiersByGroup[index]
                  .clamp(0, stage.groupSizes[index])
                  .toInt(),
          ]
        : [
            for (final groupSize in stage.groupSizes)
              fixedPerGroup > groupSize ? groupSize : fixedPerGroup,
          ];
    final fixedTotal = storedFixedByGroup.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final automaticExtraCount = (cappedParticipantCount - fixedTotal)
        .clamp(0, groupCount)
        .toInt();
    final extraCount = stage.qualificationAutoAdjust
        ? automaticExtraCount
        : (stage.extraQualifierCount ?? automaticExtraCount)
              .clamp(0, groupCount)
              .toInt();
    final extraRank = stage.extraQualifierRank ?? fixedPerGroup + 1;
    final eligibleGroupSize = extraCount == 0
        ? null
        : stage.groupSizes
              .where((size) => size >= extraRank)
              .fold<int>(0, (largest, size) => size > largest ? size : largest);

    return QualificationPlan(
      totalQualifiers: cappedParticipantCount,
      fixedPerGroup: fixedPerGroup,
      extraCount: extraCount,
      extraRank: extraRank,
      eligibleGroupSize: eligibleGroupSize,
      extraGroups: stage.qualifiersByGroup,
      fixedByGroup: storedFixedByGroup,
    );
  }

  void _addPlayer() {
    final playerName = _playerNameController.text.trim();
    if (playerName.isEmpty) {
      return;
    }

    setState(() {
      _players.add(TournamentPlayer(name: playerName, isGenerated: false));
      _playerNameController.clear();
    });
  }

  void _generatePlayers() {
    final requestedCount = int.tryParse(_playerCountController.text);
    if (requestedCount == null || requestedCount < 1) {
      return;
    }

    setState(() {
      _players
        ..clear()
        ..addAll(
          List.generate(
            requestedCount,
            (index) => TournamentPlayer.generated(index + 1),
          ),
        );
    });
  }

  void _removePlayer(int index) {
    setState(() {
      _players.removeAt(index);
    });
  }

  Future<void> _renamePlayer(int index) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => _RenamePlayerDialog(player: _players[index]),
    );

    if (newName == null || newName.trim().isEmpty) {
      return;
    }

    setState(() {
      _players[index] = _players[index].copyWith(
        name: newName.trim(),
        isGenerated: false,
      );
    });
  }

  void _saveStage() {
    final stageName = _stageNameController.text.trim();
    if (stageName.isEmpty) {
      return;
    }

    setState(() {
      final latestGroupStage = _latestGroupStage();
      final groupQualificationPlan = _selectedStageType == 'groups'
          ? _groupQualificationPlan()
          : null;
      final inheritedQualificationPlan = _selectedStageType == 'single_knockout'
          ? _storedGroupQualificationPlan(latestGroupStage)
          : null;
      final stage = TournamentStage(
        name: stageName,
        type: _selectedStageType,
        groupCount: _selectedStageType == 'groups'
            ? _calculateGroupSizes().length
            : null,
        groupSizes: _selectedStageType == 'groups'
            ? _calculateGroupSizes()
            : const [],
        groupPlayType: _selectedStageType == 'groups'
            ? _groupPlayType
            : 'round_robin',
        groupPlayTypes: _selectedStageType == 'groups'
            ? _playTypesForGroupSizes(_calculateGroupSizes())
            : const [],
        groupRoundRobinRepeats: _selectedStageType == 'groups'
            ? _roundRobinRepeatsForGroupSizes(_calculateGroupSizes())
            : const [],
        groupTieBreakers: _selectedStageType == 'groups'
            ? List.unmodifiable(_groupTieBreakers)
            : defaultGroupTieBreakers,
        knockoutParticipantCount: _selectedStageType == 'single_knockout'
            ? _knockoutParticipantCount()
            : null,
        knockoutBracketSize: _selectedStageType == 'single_knockout'
            ? _knockoutBracketSize()
            : null,
        knockoutByeCount: _selectedStageType == 'single_knockout'
            ? _knockoutByeCount()
            : 0,
        knockoutSlotOrder: _selectedStageType == 'single_knockout'
            ? _knockoutSlotOrder()
            : const [],
        knockoutSeedingMode: _selectedStageType == 'single_knockout'
            ? _knockoutSeedingMode
            : 'cross',
        qualifiersByGroup: _selectedStageType == 'groups'
            ? groupQualificationPlan?.extraGroups ?? const []
            : const [],
      fixedQualifiersByGroup: _selectedStageType == 'groups'
            ? groupQualificationPlan?.fixedByGroup ?? const []
            : const [],
        extraQualifierRank: _selectedStageType == 'groups'
            ? groupQualificationPlan?.extraRank
            : null,
        extraQualifierCount: _selectedStageType == 'groups'
            ? groupQualificationPlan?.extraCount
            : null,
        qualificationAutoAdjust: _selectedStageType == 'groups'
            ? _autoAdjustQualification
            : true,
        qualifiedParticipantCount: _selectedStageType == 'groups'
            ? groupQualificationPlan?.totalQualifiers
            : null,
        qualificationSummary: _selectedStageType == 'groups'
            ? groupQualificationPlan?.summary
            : inheritedQualificationPlan?.summary,
      );

      final editingIndex = _editingStageIndex;
      if (editingIndex == null) {
        _stages.add(stage);
      } else {
        _stages[editingIndex] = stage;
      }

      _resetStageForm();
    });
  }

  void _resetStageForm() {
    _editingStageIndex = null;
    _stageNameWasEdited = false;
    _selectedStageType = 'groups';
    _groupPlayType = 'round_robin';
    _groupPlayTypes.clear();
    _groupRoundRobinRepeats.clear();
    _fixedQualifiersByGroup.clear();
    _manualExtraRank = null;
    _manualExtraCount = null;
    _bestOfQualifierCountController.text = '0';
    _autoAdjustQualification = true;
    _selectedExtraGroups.clear();
    _groupTieBreakers
      ..clear()
      ..addAll(defaultGroupTieBreakers);
    _manualKnockoutSlotOrder = null;
    _knockoutSeedingMode = 'cross';
    _setDefaultStageNameIfNeeded();
  }

  void _editStage(int index) {
    final stage = _stages[index];
    setState(() {
      _editingStageIndex = index;
      _selectedStageType = stage.type;
      _stageNameController.text = stage.name;
      _stageNameController.selection = TextSelection.collapsed(
        offset: _stageNameController.text.length,
      );
      _stageNameWasEdited = true;

      if (stage.type == 'groups') {
        _groupCountController.text = '${stage.groupSizes.length}';
        _groupQualifierCountController.text =
            '${stage.qualifiedParticipantCount ?? stage.groupSizes.fold<int>(0, (sum, size) => sum + size)}';
        _selectedExtraGroups
          ..clear()
          ..addAll(stage.qualifiersByGroup);
        _groupPlayType = stage.groupPlayType;
        _groupPlayTypes
          ..clear()
          ..addAll(stage.groupPlayTypes);
        _groupRoundRobinRepeats
          ..clear()
          ..addAll(stage.groupRoundRobinRepeats);
        _groupTieBreakers
          ..clear()
          ..addAll(stage.groupTieBreakers);
        _fixedQualifiersByGroup
          ..clear()
          ..addAll(stage.fixedQualifiersByGroup);
        _manualExtraRank = stage.extraQualifierRank;
        _manualExtraCount = stage.extraQualifierCount;
        _bestOfQualifierCountController.text =
            '${stage.extraQualifierCount ?? 0}';
        _autoAdjustQualification = stage.qualificationAutoAdjust;
      } else {
        _selectedExtraGroups.clear();
        _groupPlayTypes.clear();
        _groupRoundRobinRepeats.clear();
        _fixedQualifiersByGroup.clear();
        _manualExtraRank = null;
        _manualExtraCount = null;
        _bestOfQualifierCountController.text = '0';
        _autoAdjustQualification = true;
        _groupTieBreakers
          ..clear()
          ..addAll(defaultGroupTieBreakers);
      }

      if (stage.type == 'single_knockout') {
        _knockoutSeedingMode = stage.knockoutSeedingMode;
        _manualKnockoutSlotOrder = stage.knockoutSlotOrder.isEmpty
            ? null
            : List<int?>.from(stage.knockoutSlotOrder);
      } else {
        _knockoutSeedingMode = 'cross';
        _manualKnockoutSlotOrder = null;
      }
    });
  }

  void _removeStage(int index) {
    setState(() {
      _stages.removeAt(index);
      if (_editingStageIndex == index) {
        _resetStageForm();
      } else if (_editingStageIndex != null && _editingStageIndex! > index) {
        _editingStageIndex = _editingStageIndex! - 1;
      }
    });
  }

  void _createTournament() {
    if (_stages.isEmpty || _players.isEmpty) {
      return;
    }

    final tournament = CreatedTournament(
      name: _tournamentNameController.text.trim().isEmpty
          ? 'Neues Turnier'
          : _tournamentNameController.text.trim(),
      players: List.unmodifiable(_players),
      stages: List.unmodifiable(_stages),
      runStages: _buildRunStages(),
    );

    TournamentStorage().saveTournament(tournament);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TournamentRunPage(tournament: tournament),
      ),
    );
  }

  List<TournamentRunStage> _buildRunStages() {
    final runStages = <TournamentRunStage>[];
    var incomingPlayers = List<TournamentPlayer>.from(_players);

    for (var stageIndex = 0; stageIndex < _stages.length; stageIndex++) {
      final stage = _stages[stageIndex];
      final requiredRank = _requiredRankAfterStage(
        stageIndex,
        incomingPlayers.length,
      );
      if (stage.type == 'groups') {
        final groups = _buildTournamentGroups(stage, incomingPlayers);
        runStages.add(
          GroupTournamentRunStage(
            name: stage.name,
            groupPlayType: stage.groupPlayType,
            groups: groups,
            qualificationPlan: _storedGroupQualificationPlan(stage),
            tieBreakers: stage.groupTieBreakers,
          ),
        );
        incomingPlayers = incomingPlayers
            .take(stage.qualifiedParticipantCount ?? incomingPlayers.length)
            .toList();
      } else if (stage.type == 'single_knockout') {
        final participantCount =
            stage.knockoutParticipantCount ?? incomingPlayers.length;
        final participants = incomingPlayers.take(participantCount).toList();
        runStages.add(
          KnockoutTournamentRunStage(
            name: stage.name,
            rounds: _buildKnockoutRounds(
              participants,
              slotOrder: stage.knockoutSlotOrder,
            ),
            placementMatches: _buildPlacementMatches(
              participants.length,
              requiredRank,
            ),
          ),
        );
        incomingPlayers = participants
            .take((participants.length + 1) ~/ 2)
            .toList();
      }
    }

    return runStages;
  }

  int _requiredRankAfterStage(int stageIndex, int availablePlayers) {
    if (stageIndex >= _stages.length - 1) {
      return 1;
    }

    final nextStage = _stages[stageIndex + 1];
    final requiredPlayers = nextStage.type == 'groups'
        ? nextStage.groupSizes.fold<int>(0, (sum, size) => sum + size)
        : nextStage.knockoutParticipantCount ?? availablePlayers;
    return requiredPlayers.clamp(1, availablePlayers).toInt();
  }

  int _requiredRankForGroup(TournamentStage stage, int groupIndex) {
    final plan = _storedGroupQualificationPlan(stage);
    if (plan == null) {
      return 1;
    }

    final fixedForGroup = groupIndex < plan.fixedByGroup.length
        ? plan.fixedByGroup[groupIndex]
        : plan.fixedPerGroup;
    final groupNumber = groupIndex + 1;
    final extraRank = plan.extraGroups.contains(groupNumber)
        ? plan.extraRank
        : 0;
    final requiredRank = fixedForGroup > extraRank ? fixedForGroup : extraRank;
    return requiredRank < 1 ? 1 : requiredRank;
  }

  List<GroupMatch> _buildPlacementMatches(
    int participantCount,
    int requiredRank,
  ) {
    if (participantCount < 4 || requiredRank < 3) {
      return const [];
    }

    final matches = <GroupMatch>[
      GroupMatch(round: 100, label: 'Spiel um Platz 3'),
    ];

    if (participantCount >= 8 && requiredRank >= 5) {
      matches.addAll([
        GroupMatch(round: 101, label: 'Platz 5 Halbfinale 1'),
        GroupMatch(round: 101, label: 'Platz 5 Halbfinale 2'),
        GroupMatch(round: 102, label: 'Spiel um Platz 5'),
        if (requiredRank >= 7)
          GroupMatch(round: 102, label: 'Spiel um Platz 7'),
      ]);
    }

    return matches;
  }

  List<TournamentGroup> _buildTournamentGroups(
    TournamentStage groupStage,
    List<TournamentPlayer> players,
  ) {
    final groups = <TournamentGroup>[];
    var playerIndex = 0;

    for (
      var groupIndex = 0;
      groupIndex < groupStage.groupSizes.length;
      groupIndex++
    ) {
      final groupPlayType = _groupPlayTypeForStage(groupStage, groupIndex);
      final groupPlayers = <TournamentPlayer>[];
      for (var slot = 0; slot < groupStage.groupSizes[groupIndex]; slot++) {
        if (playerIndex >= players.length) {
          break;
        }
        groupPlayers.add(players[playerIndex]);
        playerIndex++;
      }

      if (groupPlayType == 'mini_knockout') {
        final rounds = _buildKnockoutRounds(groupPlayers);
        final placementMatches = _buildPlacementMatches(
          groupPlayers.length,
          _requiredRankForGroup(groupStage, groupIndex),
        );
        groups.add(
          TournamentGroup(
            name: groupLabel(groupIndex + 1),
            playType: groupPlayType,
            players: groupPlayers,
            matches: [
              for (final round in rounds) ...round,
              ...placementMatches,
            ],
            knockoutRounds: rounds,
            placementMatches: placementMatches,
          ),
        );
      } else {
        groups.add(
          TournamentGroup(
            name: groupLabel(groupIndex + 1),
            playType: groupPlayType,
            players: groupPlayers,
            matches: _buildRoundRobinMatches(
              groupPlayers,
              repeatCount: _roundRobinRepeatForStage(groupStage, groupIndex),
            ),
          ),
        );
      }
    }

    return groups;
  }

  List<List<GroupMatch>> _buildKnockoutRounds(
    List<TournamentPlayer> players, {
    List<int?> slotOrder = const [],
  }) {
    if (players.length < 2) {
      return const [];
    }

    var bracketSize = 2;
    while (bracketSize < players.length) {
      bracketSize *= 2;
    }

    final slots =
        _isValidKnockoutSlotOrder(slotOrder, players.length, bracketSize) &&
            _slotOrderAvoidsByePair(slotOrder)
        ? List<int?>.from(slotOrder)
        : _automaticKnockoutSlotOrder(players.length, bracketSize);
    final rounds = <List<GroupMatch>>[];
    final firstRound = <GroupMatch>[];
    for (var index = 0; index < bracketSize; index += 2) {
      final homeSeed = slots[index];
      final awaySeed = slots[index + 1];
      firstRound.add(
        GroupMatch(
          homePlayer: homeSeed == null ? null : players[homeSeed - 1],
          awayPlayer: awaySeed == null ? null : players[awaySeed - 1],
          round: 1,
          allowsBye: true,
        ),
      );
    }
    rounds.add(firstRound);

    var matchesInRound = firstRound.length ~/ 2;
    var roundNumber = 2;
    while (matchesInRound >= 1) {
      rounds.add(
        List.generate(matchesInRound, (_) => GroupMatch(round: roundNumber)),
      );
      matchesInRound ~/= 2;
      roundNumber++;
    }

    _advanceKnockoutWinnersInRounds(rounds);
    return rounds;
  }

  void _advanceKnockoutWinnersInRounds(List<List<GroupMatch>> rounds) {
    for (var roundIndex = 0; roundIndex < rounds.length - 1; roundIndex++) {
      final currentRound = rounds[roundIndex];
      final nextRound = rounds[roundIndex + 1];
      for (var matchIndex = 0; matchIndex < currentRound.length; matchIndex++) {
        final winner = currentRound[matchIndex].winner;
        if (winner == null) {
          continue;
        }

        final targetMatch = nextRound[matchIndex ~/ 2];
        if (matchIndex.isEven) {
          targetMatch.homePlayer = winner;
        } else {
          targetMatch.awayPlayer = winner;
        }
      }
    }
  }

  void _setExtraGroupSelection(
    int groupNumber,
    bool selected,
    List<int> currentGroups,
  ) {
    setState(() {
      if (_selectedExtraGroups.isEmpty && currentGroups.isNotEmpty) {
        _selectedExtraGroups.addAll(currentGroups);
      }

      if (selected) {
        _selectedExtraGroups.add(groupNumber);
      } else {
        _selectedExtraGroups.remove(groupNumber);
      }
    });
  }

  void _setQualificationAutoAdjust(bool enabled) {
    final groupSizes = _calculateGroupSizes();
    final plan = _groupQualificationPlan();
    setState(() {
      _autoAdjustQualification = enabled;
      if (!enabled &&
          _fixedQualifiersByGroup.length != groupSizes.length &&
          plan != null) {
        _fixedQualifiersByGroup
          ..clear()
          ..addAll(_defaultFixedQualifiersForPlan(groupSizes, plan));
        _selectedExtraGroups
          ..clear()
          ..addAll(plan.extraGroups);
        _manualExtraRank = plan.extraRank;
      }
      if (enabled && plan != null) {
        _manualExtraCount = null;
        _bestOfQualifierCountController.text = '${plan.extraCount}';
      } else if (!enabled && plan != null) {
        _manualExtraCount = plan.extraCount;
        _bestOfQualifierCountController.text = '${plan.extraCount}';
      }
    });
  }

  void _setBestOfQualifierCount(String value) {
    final parsed = int.tryParse(value);
    setState(() {
      _manualExtraCount = parsed == null || parsed < 0 ? 0 : parsed;
    });
  }

  void _cycleQualificationPlace(int groupNumber, int place) {
    final groupSizes = _calculateGroupSizes();
    final plan = _groupQualificationPlan();
    if (groupNumber < 1 ||
        groupNumber > groupSizes.length ||
        place < 1 ||
        place > groupSizes[groupNumber - 1] ||
        plan == null) {
      return;
    }

    setState(() {
      final fixed = _currentFixedQualifiersByGroup(groupSizes, plan);
      final groupIndex = groupNumber - 1;
      final isFixed = place <= fixed[groupIndex];
      final isExtra =
          place == plan.extraRank && plan.extraGroups.contains(groupNumber);

      if (isExtra) {
        _selectedExtraGroups.remove(groupNumber);
      } else if (isFixed) {
        fixed[groupIndex] = place - 1;
        _manualExtraRank = place;
        _selectedExtraGroups.add(groupNumber);
      } else {
        fixed[groupIndex] = place;
        _selectedExtraGroups.remove(groupNumber);
      }

      _fixedQualifiersByGroup
        ..clear()
        ..addAll(fixed);
      if (_autoAdjustQualification) {
        final safeTotal = fixed.fold<int>(0, (sum, value) => sum + value);
        final currentExtraCount = plan.extraCount == 0 &&
                _selectedExtraGroups.isNotEmpty
            ? 1
            : plan.extraCount.clamp(0, _selectedExtraGroups.length).toInt();
        _bestOfQualifierCountController.text = '$currentExtraCount';
        _groupQualifierCountController.text = '${safeTotal + currentExtraCount}';
      }
    });
  }

  void _moveGroupTieBreaker(int index, int direction) {
    final targetIndex = index + direction;
    if (targetIndex < 0 || targetIndex >= _groupTieBreakers.length) {
      return;
    }

    setState(() {
      final moved = _groupTieBreakers.removeAt(index);
      _groupTieBreakers.insert(targetIndex, moved);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final groupSizes = _calculateGroupSizes();
    final latestGroupStage = _latestGroupStage();
    final knockoutParticipantCount = _knockoutParticipantCount();
    final knockoutBracketSize = _knockoutBracketSize();
    final knockoutByeCount = _knockoutByeCount();
    final groupQualificationPlan = _groupQualificationPlan();
    final inheritedQualificationPlan = _storedGroupQualificationPlan(
      latestGroupStage,
    );
    if (_autoAdjustQualification &&
        groupQualificationPlan != null &&
        _bestOfQualifierCountController.text !=
            '${groupQualificationPlan.extraCount}') {
      _bestOfQualifierCountController.text = '${groupQualificationPlan.extraCount}';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Turnier erstellen')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Neues Turnier',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _tournamentNameController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Turniername',
                prefixIcon: Icon(Icons.emoji_events_outlined),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Spieler',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _playerNameController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Spielername',
                      prefixIcon: Icon(Icons.person_add_alt_1_outlined),
                    ),
                    onSubmitted: (_) => _addPlayer(),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  onPressed: _addPlayer,
                  icon: const Icon(Icons.add),
                  tooltip: 'Spieler hinzufuegen',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 132,
                  child: TextField(
                    controller: _playerCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Anzahl',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _generatePlayers,
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('Spieler erzeugen'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _PlayerList(
              players: _players,
              onRenamePlayer: _renamePlayer,
              onRemovePlayer: _removePlayer,
            ),
            const SizedBox(height: 32),
            Text(
              'Etappen',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('stage-name-field'),
                    controller: _stageNameController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Etappenname',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    onChanged: (_) {
                      _stageNameWasEdited = true;
                    },
                    onSubmitted: (_) => _saveStage(),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  onPressed: _saveStage,
                  icon: Icon(
                    _editingStageIndex == null ? Icons.add : Icons.check,
                  ),
                  tooltip: _editingStageIndex == null
                      ? 'Etappe hinzufuegen'
                      : 'Etappe speichern',
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const ValueKey('stage-type-field'),
              initialValue: _selectedStageType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Etappentyp',
                prefixIcon: Icon(Icons.schema_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'groups', child: Text('Gruppenphase')),
                DropdownMenuItem(
                  value: 'single_knockout',
                  child: Text('K.-o.-Runde'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _selectedStageType = value;
                  _setDefaultStageNameIfNeeded(value);
                });
              },
            ),
            if (_selectedStageType == 'groups') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('group-play-type-field'),
                initialValue: _groupPlayType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Spieltyp',
                  prefixIcon: Icon(Icons.sports_score_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'round_robin',
                    child: Text('Jeder gegen jeden'),
                  ),
                  DropdownMenuItem(
                    value: 'mini_knockout',
                    child: Text('Mini-KO in der Gruppe'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  _setDefaultGroupPlayType(value);
                },
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 132,
                    child: TextField(
                      key: const ValueKey('group-count-field'),
                      controller: _groupCountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Gruppen',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _GroupSizePreview(groupSizes: groupSizes)),
                ],
              ),
              const SizedBox(height: 12),
              _GroupPlayTypeSetup(
                groupSizes: groupSizes,
                playTypes: _playTypesForGroupSizes(groupSizes),
                onChanged: _setGroupPlayType,
              ),
              if (_playTypesForGroupSizes(groupSizes).contains(
                'round_robin',
              )) ...[
                const SizedBox(height: 12),
                _RoundRobinRepeatsSetup(
                  groupSizes: groupSizes,
                  playTypes: _playTypesForGroupSizes(groupSizes),
                  repeats: _roundRobinRepeatsForGroupSizes(groupSizes),
                  onChangeRepeats: _changeGroupRoundRobinRepeats,
                ),
              ],
              const SizedBox(height: 12),
              _StageMatchCountPreview(
                matchCount: _currentStageMatchCount(),
                details: _currentStageMatchDetails(),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 132,
                    child: TextField(
                      key: const ValueKey('group-qualifier-count-field'),
                      controller: _groupQualifierCountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Weiter',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GroupQualificationSetup(
                      groupSizes: groupSizes,
                      groupPlayTypes: _playTypesForGroupSizes(groupSizes),
                      qualificationPlan: groupQualificationPlan,
                      autoAdjust: _autoAdjustQualification,
                      bestOfQualifierCountController:
                          _bestOfQualifierCountController,
                      onSetExtraGroup: _setExtraGroupSelection,
                      onCyclePlace: _cycleQualificationPlace,
                      onAutoAdjustChanged: _setQualificationAutoAdjust,
                      onBestOfQualifierCountChanged: _setBestOfQualifierCount,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _GroupTieBreakerSetup(
                tieBreakers: _groupTieBreakers,
                onMoveTieBreaker: _moveGroupTieBreaker,
              ),
            ],
            if (_selectedStageType == 'single_knockout') ...[
              const SizedBox(height: 12),
              _InheritedKnockoutSetup(
                previousStage: _previousStageForCurrentForm(),
                qualificationPlan: inheritedQualificationPlan,
                participantCount: knockoutParticipantCount,
                bracketSize: knockoutBracketSize,
                byeCount: knockoutByeCount,
                seedingMode: _knockoutSeedingMode,
                slotOrder: _knockoutSlotOrder(),
                participantLabels: _knockoutParticipantLabels(),
                onSeedingModeChanged: _setKnockoutSeedingMode,
                onSwapSlot: _swapKnockoutSlots,
                onResetSlots: _resetKnockoutSlots,
              ),
            ],
            if (_selectedStageType == 'single_knockout') ...[
              const SizedBox(height: 12),
              _StageMatchCountPreview(
                matchCount: _currentStageMatchCount(),
                details: _currentStageMatchDetails(),
              ),
            ],
            const SizedBox(height: 16),
            _StageList(
              stages: _stages,
              editingStageIndex: _editingStageIndex,
              onEditStage: _editStage,
              onRemoveStage: _removeStage,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _players.isEmpty || _stages.isEmpty
                  ? null
                  : _createTournament,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Turnier anlegen'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerList extends StatelessWidget {
  const _PlayerList({
    required this.players,
    required this.onRenamePlayer,
    required this.onRemovePlayer,
  });

  final List<TournamentPlayer> players;
  final void Function(int index) onRenamePlayer;
  final void Function(int index) onRemovePlayer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (players.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('Noch keine Spieler hinzugefuegt.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${players.length} Spieler im Turnier',
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < players.length; index++)
              InputChip(
                avatar: CircleAvatar(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                label: Text(players[index].name),
                tooltip: players[index].isGenerated
                    ? 'Erzeugten Spieler umbenennen'
                    : 'Spieler bearbeiten',
                onPressed: () => onRenamePlayer(index),
                onDeleted: () => onRemovePlayer(index),
                deleteIcon: const Icon(Icons.close, size: 18),
              ),
          ],
        ),
      ],
    );
  }
}

class TournamentRunPage extends StatefulWidget {
  const TournamentRunPage({super.key, required this.tournament});

  final CreatedTournament tournament;

  @override
  State<TournamentRunPage> createState() => _TournamentRunPageState();
}

class _TournamentRunPageState extends State<TournamentRunPage> {
  int _activeStageIndex = 0;
  int _viewStageIndex = 0;
  StageViewMode _stageViewMode = StageViewMode.overview;
  bool _isBracketEditMode = false;
  final Set<int> _completedStageIndexes = {};
  final _storage = TournamentStorage();

  @override
  void initState() {
    super.initState();
    _activeStageIndex = widget.tournament.activeStageIndex.clamp(
      0,
      widget.tournament.runStages.isEmpty
          ? 0
          : widget.tournament.runStages.length - 1,
    );
    _viewStageIndex = _activeStageIndex;
    _completedStageIndexes.addAll(widget.tournament.completedStageIndexes);
    _advanceKnockoutWinners();
    _ensureGroupDeciders();
  }

  Future<void> _saveTournamentProgress() async {
    widget.tournament.activeStageIndex = _activeStageIndex;
    widget.tournament.completedStageIndexes
      ..clear()
      ..addAll(_completedStageIndexes);
    await _storage.saveTournament(widget.tournament);
  }

  Future<void> _editResult(GroupMatch match) async {
    final result = await showDialog<MatchResult>(
      context: context,
      builder: (context) => _ResultDialog(match: match),
    );

    if (result == null) {
      return;
    }

    setState(() {
      match.isAnnulled = result.isAnnulled;
      if (result.isAnnulled) {
        match.homeLegs = null;
        match.awayLegs = null;
      } else {
        match.homeLegs = result.homeLegs;
        match.awayLegs = result.awayLegs;
      }
      _advanceKnockoutWinners();
      _ensureGroupDeciders();
    });
    await _saveTournamentProgress();
  }

  bool _canEditKnockoutBracket(KnockoutTournamentRunStage stage) {
    return stage.rounds.isNotEmpty &&
        stage.rounds.first.isNotEmpty &&
        stage.matches.every((match) => !match.isResolved);
  }

  Future<void> _swapKnockoutRunSlots(
    KnockoutTournamentRunStage stage,
    int fromSlotIndex,
    int toSlotIndex,
  ) async {
    if (!_canEditKnockoutBracket(stage) ||
        fromSlotIndex == toSlotIndex ||
        fromSlotIndex < 0 ||
        toSlotIndex < 0) {
      return;
    }

    final firstRound = stage.rounds.first;
    final maxSlotIndex = firstRound.length * 2 - 1;
    if (fromSlotIndex > maxSlotIndex || toSlotIndex > maxSlotIndex) {
      return;
    }

    setState(() {
      final fromPlayer = _playerAtFirstRoundSlot(firstRound, fromSlotIndex);
      final toPlayer = _playerAtFirstRoundSlot(firstRound, toSlotIndex);
      _setPlayerAtFirstRoundSlot(firstRound, fromSlotIndex, toPlayer);
      _setPlayerAtFirstRoundSlot(firstRound, toSlotIndex, fromPlayer);
      _clearKnockoutProgress(stage.rounds);
      _clearPlacementMatches(stage.placementMatches);
      _advanceKnockoutWinners();
    });
    await _saveTournamentProgress();
  }

  TournamentPlayer? _playerAtFirstRoundSlot(
    List<GroupMatch> firstRound,
    int slotIndex,
  ) {
    final match = firstRound[slotIndex ~/ 2];
    return slotIndex.isEven ? match.homePlayer : match.awayPlayer;
  }

  void _setPlayerAtFirstRoundSlot(
    List<GroupMatch> firstRound,
    int slotIndex,
    TournamentPlayer? player,
  ) {
    final match = firstRound[slotIndex ~/ 2];
    if (slotIndex.isEven) {
      match.homePlayer = player;
    } else {
      match.awayPlayer = player;
    }
  }

  void _clearKnockoutProgress(List<List<GroupMatch>> rounds) {
    for (var roundIndex = 0; roundIndex < rounds.length; roundIndex++) {
      for (final match in rounds[roundIndex]) {
        match.homeLegs = null;
        match.awayLegs = null;
        match.isAnnulled = false;
        if (roundIndex > 0) {
          match.homePlayer = null;
          match.awayPlayer = null;
        }
      }
    }
  }

  void _clearPlacementMatches(List<GroupMatch> matches) {
    for (final match in matches) {
      match.homePlayer = null;
      match.awayPlayer = null;
      match.homeLegs = null;
      match.awayLegs = null;
      match.isAnnulled = false;
    }
  }

  void _advanceKnockoutWinners() {
    for (final stage in widget.tournament.runStages) {
      if (stage is KnockoutTournamentRunStage) {
        _advanceWinnersInRounds(stage.rounds);
        _advancePlacementMatches(stage.rounds, stage.placementMatches);
      }

      if (stage is GroupTournamentRunStage) {
        for (final group in stage.groups) {
          if (group.playType == 'mini_knockout') {
            _advanceWinnersInRounds(group.knockoutRounds);
            _advancePlacementMatches(
              group.knockoutRounds,
              group.placementMatches,
            );
          }
        }
      }
    }
  }

  void _advanceWinnersInRounds(List<List<GroupMatch>> rounds) {
    for (var roundIndex = 0; roundIndex < rounds.length - 1; roundIndex++) {
      final currentRound = rounds[roundIndex];
      final nextRound = rounds[roundIndex + 1];
      for (var matchIndex = 0; matchIndex < currentRound.length; matchIndex++) {
        final winner = currentRound[matchIndex].winner;
        final targetMatch = nextRound[matchIndex ~/ 2];
        if (matchIndex.isEven) {
          if (targetMatch.homePlayer != winner) {
            targetMatch.homeLegs = null;
            targetMatch.awayLegs = null;
            targetMatch.isAnnulled = false;
          }
          targetMatch.homePlayer = winner;
        } else {
          if (targetMatch.awayPlayer != winner) {
            targetMatch.homeLegs = null;
            targetMatch.awayLegs = null;
            targetMatch.isAnnulled = false;
          }
          targetMatch.awayPlayer = winner;
        }
      }
    }
  }

  void _ensureGroupDeciders() {
    for (final stage in widget.tournament.runStages) {
      if (stage is! GroupTournamentRunStage) {
        continue;
      }

      for (var groupIndex = 0; groupIndex < stage.groups.length; groupIndex++) {
        final group = stage.groups[groupIndex];
        if (group.playType != 'round_robin') {
          continue;
        }
        _ensureDecidersForGroup(stage, group, groupIndex);
      }
    }
  }

  void _ensureDecidersForGroup(
    GroupTournamentRunStage stage,
    TournamentGroup group,
    int groupIndex,
  ) {
    final regularMatches = group.matches
        .where((match) => !match.isDecider)
        .toList();
    if (regularMatches.any((match) => match.hasPlayers && !match.isResolved)) {
      return;
    }

    final standings = _standingsFor(group, stage.tieBreakers);
    final relevantPlaces = _relevantPlacesForDeciders(stage, groupIndex);
    if (relevantPlaces.isEmpty) {
      return;
    }

    for (final place in relevantPlaces) {
      final index = place - 1;
      if (index < 0 || index >= standings.length) {
        continue;
      }

      final tied = <PlayerStanding>[standings[index]];
      for (var above = index - 1; above >= 0; above--) {
        if (_compareTieBreakersOnly(
              standings[index],
              standings[above],
              stage.tieBreakers,
              group.matches,
            ) !=
            0) {
          break;
        }
        tied.add(standings[above]);
      }
      for (var below = index + 1; below < standings.length; below++) {
        if (_compareTieBreakersOnly(
              standings[index],
              standings[below],
              stage.tieBreakers,
              group.matches,
            ) !=
            0) {
          break;
        }
        tied.add(standings[below]);
      }

      if (tied.length < 2) {
        continue;
      }

      for (var first = 0; first < tied.length; first++) {
        for (var second = first + 1; second < tied.length; second++) {
          _addDeciderIfMissing(
            group,
            tied[first].player,
            tied[second].player,
          );
        }
      }
    }
  }

  Set<int> _relevantPlacesForDeciders(
    GroupTournamentRunStage stage,
    int groupIndex,
  ) {
    final plan = stage.qualificationPlan;
    if (plan == null) {
      return const {};
    }

    final fixedForGroup = groupIndex < plan.fixedByGroup.length
        ? plan.fixedByGroup[groupIndex]
        : plan.fixedPerGroup;
    final groupNumber = groupIndex + 1;
    return {
      for (var place = 1; place <= fixedForGroup; place++) place,
      if (plan.extraGroups.contains(groupNumber)) plan.extraRank,
    };
  }

  int _compareTieBreakersOnly(
    PlayerStanding a,
    PlayerStanding b,
    List<String> tieBreakers,
    List<GroupMatch> matches,
  ) {
    for (final tieBreaker in tieBreakers) {
      final comparison = switch (tieBreaker) {
        'points' => b.points.compareTo(a.points),
        'legDifference' => b.legDifference.compareTo(a.legDifference),
        'legsFor' => b.legsFor.compareTo(a.legsFor),
        'headToHead' => _compareHeadToHead(a, b, matches),
        _ => 0,
      };

      if (comparison != 0) {
        return comparison;
      }
    }

    return 0;
  }

  void _addDeciderIfMissing(
    TournamentGroup group,
    TournamentPlayer first,
    TournamentPlayer second,
  ) {
    final alreadyExists = group.matches.any((match) {
      if (!match.isDecider) {
        return false;
      }
      final home = match.homePlayer;
      final away = match.awayPlayer;
      return (home == first && away == second) || (home == second && away == first);
    });
    if (alreadyExists) {
      return;
    }

    group.matches.add(
      GroupMatch(
        homePlayer: first,
        awayPlayer: second,
        round: _nextDeciderRound(group),
        label: 'Decider',
        isDecider: true,
      ),
    );
  }

  int _nextDeciderRound(TournamentGroup group) {
    final highestRound = group.matches.fold<int>(
      0,
      (highest, match) => match.round > highest ? match.round : highest,
    );
    return highestRound + 1;
  }

  void _advancePlacementMatches(
    List<List<GroupMatch>> rounds,
    List<GroupMatch> placementMatches,
  ) {
    if (rounds.length >= 2 && placementMatches.isNotEmpty) {
      final semifinalLosers = rounds[rounds.length - 2]
          .map((match) => match.loser)
          .whereType<TournamentPlayer>()
          .toList();
      final thirdPlaceMatches = placementMatches
          .where((match) => match.label == 'Spiel um Platz 3')
          .toList();
      final thirdPlaceMatch = thirdPlaceMatches.isEmpty
          ? null
          : thirdPlaceMatches.first;
      if (thirdPlaceMatch != null && semifinalLosers.length >= 2) {
        _setMatchPlayers(
          thirdPlaceMatch,
          semifinalLosers[0],
          semifinalLosers[1],
        );
      }
    }

    if (rounds.length >= 3 && placementMatches.length >= 4) {
      final quarterfinalLosers = rounds[rounds.length - 3]
          .map((match) => match.loser)
          .whereType<TournamentPlayer>()
          .toList();
      final fifthSemis = placementMatches
          .where(
            (match) => match.label?.startsWith('Platz 5 Halbfinale') ?? false,
          )
          .toList();
      if (quarterfinalLosers.length >= 4 && fifthSemis.length >= 2) {
        _setMatchPlayers(
          fifthSemis[0],
          quarterfinalLosers[0],
          quarterfinalLosers[1],
        );
        _setMatchPlayers(
          fifthSemis[1],
          quarterfinalLosers[2],
          quarterfinalLosers[3],
        );
      }

      final fifthFinalMatches = placementMatches
          .where((match) => match.label == 'Spiel um Platz 5')
          .toList();
      final fifthFinal = fifthFinalMatches.isEmpty
          ? null
          : fifthFinalMatches.first;
      if (fifthFinal != null && fifthSemis.length >= 2) {
        _setMatchPlayers(fifthFinal, fifthSemis[0].winner, fifthSemis[1].winner);
      }

      final seventhPlaceMatches = placementMatches
          .where((match) => match.label == 'Spiel um Platz 7')
          .toList();
      if (seventhPlaceMatches.isNotEmpty && fifthSemis.length >= 2) {
        _setMatchPlayers(
          seventhPlaceMatches.first,
          fifthSemis[0].loser,
          fifthSemis[1].loser,
        );
      }
    }
  }

  void _setMatchPlayers(
    GroupMatch match,
    TournamentPlayer? homePlayer,
    TournamentPlayer? awayPlayer,
  ) {
    if (match.homePlayer != homePlayer || match.awayPlayer != awayPlayer) {
      match.homeLegs = null;
      match.awayLegs = null;
      match.isAnnulled = false;
    }
    match.homePlayer = homePlayer;
    match.awayPlayer = awayPlayer;
  }

  List<PlayerStanding> _standingsFor(
    TournamentGroup group,
    List<String> tieBreakers,
  ) {
    final standings = {
      for (final player in group.players) player.name: PlayerStanding(player),
    };

    for (final match in group.matches.where(
      (match) => match.hasResult && !match.isDecider,
    )) {
      final homePlayer = match.homePlayer!;
      final awayPlayer = match.awayPlayer!;
      final home = standings[homePlayer.name]!;
      final away = standings[awayPlayer.name]!;
      final homeLegs = match.homeLegs!;
      final awayLegs = match.awayLegs!;

      home.played++;
      home.legsFor += homeLegs;
      home.legsAgainst += awayLegs;
      away.played++;
      away.legsFor += awayLegs;
      away.legsAgainst += homeLegs;

      if (homeLegs > awayLegs) {
        home.wins++;
        home.points += 3;
        away.losses++;
      } else if (awayLegs > homeLegs) {
        away.wins++;
        away.points += 3;
        home.losses++;
      } else {
        home.draws++;
        home.points++;
        away.draws++;
        away.points++;
      }
    }

    final sorted = standings.values.toList();
    sorted.sort((a, b) {
      final comparison = _compareStandings(
        a,
        b,
        tieBreakers,
        matches: group.matches,
      );
      if (comparison != 0) {
        return comparison;
      }
      return a.player.name.compareTo(b.player.name);
    });

    return sorted;
  }

  int _compareStandings(
    PlayerStanding a,
    PlayerStanding b,
    List<String> tieBreakers, {
    List<GroupMatch> matches = const [],
  }) {
    for (final tieBreaker in tieBreakers) {
      final comparison = switch (tieBreaker) {
        'points' => b.points.compareTo(a.points),
        'legDifference' => b.legDifference.compareTo(a.legDifference),
        'legsFor' => b.legsFor.compareTo(a.legsFor),
        'headToHead' => _compareHeadToHead(a, b, matches),
        _ => 0,
      };

      if (comparison != 0) {
        return comparison;
      }
    }

    return _compareDecider(a, b, matches);
  }

  int _compareDecider(
    PlayerStanding a,
    PlayerStanding b,
    List<GroupMatch> matches,
  ) {
    for (final match in matches.where((match) => match.isDecider && match.hasResult)) {
      final home = match.homePlayer!;
      final away = match.awayPlayer!;
      final isDirectMatch =
          (home.name == a.player.name && away.name == b.player.name) ||
          (home.name == b.player.name && away.name == a.player.name);
      if (!isDirectMatch || match.winner == null) {
        continue;
      }
      return match.winner!.name == a.player.name ? -1 : 1;
    }

    return 0;
  }

  int _compareHeadToHead(
    PlayerStanding a,
    PlayerStanding b,
    List<GroupMatch> matches,
  ) {
    var aPoints = 0;
    var bPoints = 0;
    var aLegs = 0;
    var bLegs = 0;

    for (final match in matches.where(
      (match) => match.hasResult && !match.isDecider,
    )) {
      final home = match.homePlayer!;
      final away = match.awayPlayer!;
      final isDirectMatch =
          (home.name == a.player.name && away.name == b.player.name) ||
          (home.name == b.player.name && away.name == a.player.name);
      if (!isDirectMatch) {
        continue;
      }

      final aIsHome = home.name == a.player.name;
      final aMatchLegs = aIsHome ? match.homeLegs! : match.awayLegs!;
      final bMatchLegs = aIsHome ? match.awayLegs! : match.homeLegs!;
      aLegs += aMatchLegs;
      bLegs += bMatchLegs;

      if (aMatchLegs > bMatchLegs) {
        aPoints += 3;
      } else if (bMatchLegs > aMatchLegs) {
        bPoints += 3;
      } else {
        aPoints++;
        bPoints++;
      }
    }

    final pointCompare = bPoints.compareTo(aPoints);
    if (pointCompare != 0) return pointCompare;
    final diffCompare = (bLegs - aLegs).compareTo(aLegs - bLegs);
    if (diffCompare != 0) return diffCompare;
    return bLegs.compareTo(aLegs);
  }

  bool _stageHasOpenMatches(TournamentRunStage stage) {
    if (stage is KnockoutTournamentRunStage) {
      return !_knockoutHasWinner(stage) || _hasOpenPlacementMatches(stage.placementMatches);
    }
    if (stage is GroupTournamentRunStage) {
      return stage.groups.any((group) {
        if (group.playType == 'mini_knockout') {
          return !_miniKnockoutGroupHasWinner(group) ||
              _hasOpenPlacementMatches(group.placementMatches);
        }

        return group.matches.any((match) => !match.isResolved);
      });
    }

    return _matchesForStage(stage).any((match) => !match.isResolved);
  }

  bool _hasOpenPlacementMatches(List<GroupMatch> matches) {
    return matches.any((match) => match.hasPlayers && !match.isResolved);
  }

  bool _knockoutHasWinner(KnockoutTournamentRunStage stage) {
    return stage.rounds.isNotEmpty &&
        stage.rounds.last.length == 1 &&
        stage.rounds.last.first.winner != null;
  }

  bool _miniKnockoutGroupHasWinner(TournamentGroup group) {
    return group.knockoutRounds.isNotEmpty &&
        group.knockoutRounds.last.length == 1 &&
        group.knockoutRounds.last.first.winner != null;
  }

  List<GroupMatch> _matchesForStage(TournamentRunStage stage) {
    if (stage is GroupTournamentRunStage) {
      return [for (final group in stage.groups) ...group.matches];
    }
    if (stage is KnockoutTournamentRunStage) {
      return stage.matches;
    }

    return const [];
  }

  int _requiredRankForRunStage(int stageIndex) {
    if (stageIndex >= widget.tournament.stages.length - 1) {
      return 1;
    }

    final stage = widget.tournament.runStages[stageIndex];
    final availablePlayers = _participantCountForRunStage(stage);
    final nextStage = widget.tournament.stages[stageIndex + 1];
    final requiredPlayers = nextStage.type == 'groups'
        ? nextStage.groupSizes.fold<int>(0, (sum, size) => sum + size)
        : nextStage.knockoutParticipantCount ?? availablePlayers;
    return requiredPlayers.clamp(1, availablePlayers).toInt();
  }

  int _participantCountForRunStage(TournamentRunStage stage) {
    if (stage is KnockoutTournamentRunStage) {
      if (stage.rounds.isEmpty) {
        return 0;
      }
      return stage.rounds.first.fold<int>(
        0,
        (sum, match) =>
            sum +
            (match.homePlayer == null ? 0 : 1) +
            (match.awayPlayer == null ? 0 : 1),
      );
    }
    if (stage is GroupTournamentRunStage) {
      return stage.groups.fold<int>(
        0,
        (sum, group) => sum + group.players.length,
      );
    }
    return 0;
  }

  List<TournamentPlayer> _advancingPlayersFromStage(TournamentRunStage stage) {
    if (stage is GroupTournamentRunStage) {
      return _advancingPlayersFromGroupStage(stage);
    }

    if (stage is KnockoutTournamentRunStage) {
      return _knockoutRanking(
        stage.rounds,
        stage.placementMatches,
        fallbackPlayers: const [],
      );
    }

    return const [];
  }

  TournamentRunStage _stageForView(int stageIndex) {
    if (stageIndex <= _activeStageIndex) {
      return widget.tournament.runStages[stageIndex];
    }

    var incomingPlayers = _advancingPlayersFromStage(
      widget.tournament.runStages[_activeStageIndex],
    );
    late TournamentRunStage previewStage;

    for (
      var index = _activeStageIndex + 1;
      index <= stageIndex && index < widget.tournament.stages.length;
      index++
    ) {
      previewStage = _buildRunStageFromPlayers(
        widget.tournament.stages[index],
        incomingPlayers,
      );
      if (index < stageIndex) {
        incomingPlayers = _advancingPlayersFromStage(previewStage);
      }
    }

    return previewStage;
  }

  List<TournamentPlayer> _advancingPlayersFromGroupStage(
    GroupTournamentRunStage stage,
  ) {
    if (stage.groups.any((group) => group.playType == 'mini_knockout')) {
      return _advancingPlayersFromMixedGroups(stage);
    }

    final plan = stage.qualificationPlan;
    if (plan == null) {
      return [
        for (final group in stage.groups)
          for (final standing in _standingsFor(group, stage.tieBreakers))
            standing.player,
      ];
    }

    final advancingPlayers = <TournamentPlayer>[];
    final extraCandidates = <PlayerStanding>[];

    for (var groupIndex = 0; groupIndex < stage.groups.length; groupIndex++) {
      final groupNumber = groupIndex + 1;
      final standings = _standingsFor(
        stage.groups[groupIndex],
        stage.tieBreakers,
      );

      final fixedForGroup = groupIndex < plan.fixedByGroup.length
          ? plan.fixedByGroup[groupIndex]
          : plan.fixedPerGroup;
      advancingPlayers.addAll(
        standings.take(fixedForGroup).map((standing) => standing.player),
      );

      final extraIndex = plan.extraRank - 1;
      if (plan.extraGroups.contains(groupNumber) &&
          extraIndex >= 0 &&
          extraIndex < standings.length) {
        extraCandidates.add(standings[extraIndex]);
      }
    }

    extraCandidates.sort((a, b) => _compareStandings(a, b, stage.tieBreakers));
    advancingPlayers.addAll(
      extraCandidates.take(plan.extraCount).map((standing) => standing.player),
    );

    return advancingPlayers;
  }

  List<TournamentPlayer> _advancingPlayersFromMixedGroups(GroupTournamentRunStage stage) {
    final plan = stage.qualificationPlan;
    if (plan == null) {
      return [
        for (final group in stage.groups)
          ..._orderedPlayersForGroup(stage, group),
      ];
    }

    final advancingPlayers = <TournamentPlayer>[];
    final extraCandidates = <TournamentPlayer>[];

    for (var groupIndex = 0; groupIndex < stage.groups.length; groupIndex++) {
      final groupNumber = groupIndex + 1;
      final ranking = _orderedPlayersForGroup(stage, stage.groups[groupIndex]);

      final fixedForGroup = groupIndex < plan.fixedByGroup.length
          ? plan.fixedByGroup[groupIndex]
          : plan.fixedPerGroup;
      advancingPlayers.addAll(ranking.take(fixedForGroup));

      final extraIndex = plan.extraRank - 1;
      if (plan.extraGroups.contains(groupNumber) &&
          extraIndex >= 0 &&
          extraIndex < ranking.length) {
        extraCandidates.add(ranking[extraIndex]);
      }
    }

    advancingPlayers.addAll(extraCandidates.take(plan.extraCount));
    return advancingPlayers;
  }

  List<TournamentPlayer> _orderedPlayersForGroup(
    GroupTournamentRunStage stage,
    TournamentGroup group,
  ) {
    if (group.playType == 'mini_knockout') {
      return _miniKnockoutRankingForGroup(group);
    }

    return _standingsFor(group, stage.tieBreakers)
        .map((standing) => standing.player)
        .toList();
  }

  List<TournamentPlayer> _miniKnockoutRankingForGroup(TournamentGroup group) {
    return _knockoutRanking(
      group.knockoutRounds,
      group.placementMatches,
      fallbackPlayers: group.players,
    );
  }

  List<TournamentPlayer> _knockoutRanking(
    List<List<GroupMatch>> rounds,
    List<GroupMatch> placementMatches, {
    required List<TournamentPlayer> fallbackPlayers,
  }) {
    final rankedPlayers = <TournamentPlayer>[];

    void addPlayer(TournamentPlayer? player) {
      if (player == null) {
        return;
      }
      if (rankedPlayers.any((ranked) => ranked.name == player.name)) {
        return;
      }
      rankedPlayers.add(player);
    }

    if (rounds.isNotEmpty) {
      addPlayer(rounds.last.first.winner);
      addPlayer(rounds.last.first.loser);

      final thirdPlaceMatches = placementMatches
          .where((match) => match.label == 'Spiel um Platz 3')
          .toList();
      if (thirdPlaceMatches.isNotEmpty) {
        addPlayer(thirdPlaceMatches.first.winner);
        addPlayer(thirdPlaceMatches.first.loser);
      } else if (rounds.length >= 2) {
        for (final match in rounds[rounds.length - 2]) {
          addPlayer(match.loser);
        }
      }

      final fifthPlaceMatches = placementMatches
          .where((match) => match.label == 'Spiel um Platz 5')
          .toList();
      if (fifthPlaceMatches.isNotEmpty) {
        addPlayer(fifthPlaceMatches.first.winner);
        addPlayer(fifthPlaceMatches.first.loser);
      }

      final seventhPlaceMatches = placementMatches
          .where((match) => match.label == 'Spiel um Platz 7')
          .toList();
      if (seventhPlaceMatches.isNotEmpty) {
        addPlayer(seventhPlaceMatches.first.winner);
        addPlayer(seventhPlaceMatches.first.loser);
      }

      for (var roundIndex = rounds.length - 1; roundIndex >= 0; roundIndex--) {
        for (final match in rounds[roundIndex]) {
          addPlayer(match.loser);
        }
      }
    }

    for (final player in fallbackPlayers) {
      addPlayer(player);
    }

    return rankedPlayers;
  }

  TournamentRunStage _buildRunStageFromPlayers(
    TournamentStage stage,
    List<TournamentPlayer> players,
  ) {
    if (stage.type == 'single_knockout') {
      final participantCount = stage.knockoutParticipantCount == null
          ? players.length
          : stage.knockoutParticipantCount!.clamp(0, players.length).toInt();
      final participants = players.take(participantCount).toList();
      return KnockoutTournamentRunStage(
        name: stage.name,
        rounds: _buildKnockoutRoundsForPlayers(
          participants,
          slotOrder: stage.knockoutSlotOrder,
        ),
        placementMatches: _buildPlacementMatchesForPlayers(
          participants.length,
          1,
        ),
      );
    }

    return GroupTournamentRunStage(
      name: stage.name,
      groupPlayType: stage.groupPlayType,
      groups: _buildTournamentGroupsForPlayers(stage, players),
      qualificationPlan: _qualificationPlanForStage(stage),
      tieBreakers: stage.groupTieBreakers,
    );
  }

  QualificationPlan? _qualificationPlanForStage(TournamentStage stage) {
    if (stage.groupSizes.isEmpty || stage.qualifiedParticipantCount == null) {
      return null;
    }

    final groupCount = stage.groupSizes.length;
    final maxQualifiers = stage.groupSizes.fold<int>(
      0,
      (sum, size) => sum + size,
    );
    final totalQualifiers = stage.qualifiedParticipantCount! > maxQualifiers
        ? maxQualifiers
        : stage.qualifiedParticipantCount!;
    final fixedPerGroup = totalQualifiers ~/ groupCount;
    final fixedByGroup = stage.fixedQualifiersByGroup.length == groupCount
        ? [
            for (var index = 0; index < groupCount; index++)
              stage.fixedQualifiersByGroup[index]
                  .clamp(0, stage.groupSizes[index])
                  .toInt(),
          ]
        : [
            for (final groupSize in stage.groupSizes)
              fixedPerGroup > groupSize ? groupSize : fixedPerGroup,
          ];
    final fixedTotal = fixedByGroup.fold<int>(0, (sum, value) => sum + value);
    final automaticExtraCount = (totalQualifiers - fixedTotal)
        .clamp(0, groupCount)
        .toInt();
    final extraCount = stage.qualificationAutoAdjust
        ? automaticExtraCount
        : (stage.extraQualifierCount ?? automaticExtraCount)
              .clamp(0, groupCount)
              .toInt();
    final extraRank = stage.extraQualifierRank ?? fixedPerGroup + 1;
    final extraGroups = extraCount == 0
        ? const <int>[]
        : stage.qualifiersByGroup.isNotEmpty
        ? stage.qualifiersByGroup
        : [
            for (var index = 0; index < stage.groupSizes.length; index++)
              if (stage.groupSizes[index] >= extraRank) index + 1,
          ];
    final eligibleGroupSize = extraCount == 0
        ? null
        : stage.groupSizes
              .where((size) => size >= extraRank)
              .fold<int>(0, (largest, size) => size > largest ? size : largest);

    return QualificationPlan(
      totalQualifiers: totalQualifiers,
      fixedPerGroup: fixedPerGroup,
      extraCount: extraCount,
      extraRank: extraRank,
      eligibleGroupSize: eligibleGroupSize,
      extraGroups: extraGroups,
      fixedByGroup: fixedByGroup,
    );
  }

  int _requiredRankForStageGroup(TournamentStage stage, int groupIndex) {
    final plan = _qualificationPlanForStage(stage);
    if (plan == null) {
      return 1;
    }

    final fixedForGroup = groupIndex < plan.fixedByGroup.length
        ? plan.fixedByGroup[groupIndex]
        : plan.fixedPerGroup;
    final groupNumber = groupIndex + 1;
    final extraRank = plan.extraGroups.contains(groupNumber)
        ? plan.extraRank
        : 0;
    final requiredRank = fixedForGroup > extraRank ? fixedForGroup : extraRank;
    return requiredRank < 1 ? 1 : requiredRank;
  }

  List<GroupMatch> _buildPlacementMatchesForPlayers(
    int participantCount,
    int requiredRank,
  ) {
    if (participantCount < 4 || requiredRank < 3) {
      return const [];
    }

    final matches = <GroupMatch>[
      GroupMatch(round: 100, label: 'Spiel um Platz 3'),
    ];

    if (participantCount >= 8 && requiredRank >= 5) {
      matches.addAll([
        GroupMatch(round: 101, label: 'Platz 5 Halbfinale 1'),
        GroupMatch(round: 101, label: 'Platz 5 Halbfinale 2'),
        GroupMatch(round: 102, label: 'Spiel um Platz 5'),
        if (requiredRank >= 7)
          GroupMatch(round: 102, label: 'Spiel um Platz 7'),
      ]);
    }

    return matches;
  }

  List<TournamentGroup> _buildTournamentGroupsForPlayers(
    TournamentStage stage,
    List<TournamentPlayer> players,
  ) {
    final groups = <TournamentGroup>[];
    var playerIndex = 0;

    for (
      var groupIndex = 0;
      groupIndex < stage.groupSizes.length;
      groupIndex++
    ) {
      final groupPlayType = _groupPlayTypeForStage(stage, groupIndex);
      final groupPlayers = <TournamentPlayer>[];
      for (var slot = 0; slot < stage.groupSizes[groupIndex]; slot++) {
        if (playerIndex >= players.length) {
          break;
        }
        groupPlayers.add(players[playerIndex]);
        playerIndex++;
      }

      if (groupPlayType == 'mini_knockout') {
        final rounds = _buildKnockoutRoundsForPlayers(groupPlayers);
        final placementMatches = _buildPlacementMatchesForPlayers(
          groupPlayers.length,
          _requiredRankForStageGroup(stage, groupIndex),
        );
        groups.add(
          TournamentGroup(
            name: groupLabel(groupIndex + 1),
            playType: groupPlayType,
            players: groupPlayers,
            matches: [
              for (final round in rounds) ...round,
              ...placementMatches,
            ],
            knockoutRounds: rounds,
            placementMatches: placementMatches,
          ),
        );
      } else {
        groups.add(
          TournamentGroup(
            name: groupLabel(groupIndex + 1),
            playType: groupPlayType,
            players: groupPlayers,
            matches: _buildRoundRobinMatchesForPlayers(
              groupPlayers,
              repeatCount: _roundRobinRepeatForStage(stage, groupIndex),
            ),
          ),
        );
      }
    }

    return groups;
  }

  List<List<GroupMatch>> _buildKnockoutRoundsForPlayers(
    List<TournamentPlayer> players, {
    List<int?> slotOrder = const [],
  }) {
    if (players.length < 2) {
      return const [];
    }

    var bracketSize = 2;
    while (bracketSize < players.length) {
      bracketSize *= 2;
    }

    final slots =
        _isValidSlotOrder(slotOrder, players.length, bracketSize) &&
            _slotOrderAvoidsByePair(slotOrder)
        ? List<int?>.from(slotOrder)
        : _automaticSlotOrder(players.length, bracketSize);
    final rounds = <List<GroupMatch>>[];
    final firstRound = <GroupMatch>[];
    for (var index = 0; index < bracketSize; index += 2) {
      final homeSeed = slots[index];
      final awaySeed = slots[index + 1];
      firstRound.add(
        GroupMatch(
          homePlayer: homeSeed == null ? null : players[homeSeed - 1],
          awayPlayer: awaySeed == null ? null : players[awaySeed - 1],
          round: 1,
          allowsBye: true,
        ),
      );
    }
    rounds.add(firstRound);

    var matchesInRound = firstRound.length ~/ 2;
    var roundNumber = 2;
    while (matchesInRound >= 1) {
      rounds.add(
        List.generate(matchesInRound, (_) => GroupMatch(round: roundNumber)),
      );
      matchesInRound ~/= 2;
      roundNumber++;
    }

    _advanceKnockoutWinnersInBuiltRounds(rounds);
    return rounds;
  }

  void _advanceKnockoutWinnersInBuiltRounds(List<List<GroupMatch>> rounds) {
    for (var roundIndex = 0; roundIndex < rounds.length - 1; roundIndex++) {
      final currentRound = rounds[roundIndex];
      final nextRound = rounds[roundIndex + 1];
      for (var matchIndex = 0; matchIndex < currentRound.length; matchIndex++) {
        final winner = currentRound[matchIndex].winner;
        if (winner == null) {
          continue;
        }

        final targetMatch = nextRound[matchIndex ~/ 2];
        if (matchIndex.isEven) {
          targetMatch.homePlayer = winner;
        } else {
          targetMatch.awayPlayer = winner;
        }
      }
    }
  }

  List<GroupMatch> _buildRoundRobinMatchesForPlayers(
    List<TournamentPlayer> players, {
    int repeatCount = 1,
  }) {
    return _buildRoundRobinMatches(players, repeatCount: repeatCount);
  }

  List<int?> _automaticSlotOrder(int participantCount, int bracketSize) {
    return [
      for (final seed in _seedOrder(bracketSize))
        seed <= participantCount ? seed : null,
    ];
  }

  List<int> _seedOrder(int bracketSize) {
    var order = <int>[1, 2];
    var size = 2;
    while (size < bracketSize) {
      final nextSize = size * 2;
      order = [
        for (final seed in order) ...[seed, nextSize + 1 - seed],
      ];
      size = nextSize;
    }

    return order;
  }

  bool _isValidSlotOrder(
    List<int?> slotOrder,
    int participantCount,
    int bracketSize,
  ) {
    if (slotOrder.length != bracketSize) {
      return false;
    }

    final values = slotOrder.whereType<int>().toList()..sort();
    if (values.length != participantCount) {
      return false;
    }

    for (var index = 0; index < values.length; index++) {
      if (values[index] != index + 1) {
        return false;
      }
    }

    return true;
  }

  bool _slotOrderAvoidsByePair(List<int?> slotOrder) {
    for (var index = 0; index < slotOrder.length; index += 2) {
      final first = slotOrder[index];
      final second = index + 1 < slotOrder.length ? slotOrder[index + 1] : null;
      if (first == null && second == null) {
        return false;
      }
    }
    return true;
  }

  void _completeCurrentStage() {
    setState(() {
      if (_activeStageIndex < widget.tournament.runStages.length - 1) {
        final advancingPlayers = _advancingPlayersFromStage(
          widget.tournament.runStages[_activeStageIndex],
        );
        final nextStageConfig = widget.tournament.stages[_activeStageIndex + 1];
        widget.tournament.runStages[_activeStageIndex + 1] =
            _buildRunStageFromPlayers(nextStageConfig, advancingPlayers);
      }

      _completedStageIndexes.add(_activeStageIndex);
      if (_activeStageIndex < widget.tournament.runStages.length - 1) {
        _activeStageIndex++;
      }
      _viewStageIndex = _activeStageIndex;
    });
    _advanceKnockoutWinners();
    _saveTournamentProgress();
  }

  void _finishCurrentStageEarly() {
    setState(() {
      for (final match in _matchesForStage(
        widget.tournament.runStages[_activeStageIndex],
      )) {
        if (match.hasPlayers && !match.isResolved) {
          match.isAnnulled = true;
          match.homeLegs = null;
          match.awayLegs = null;
        }
      }
      _advanceKnockoutWinners();
    });
    _completeCurrentStage();
  }

  @override
  Widget build(BuildContext context) {
    final activeStage = _stageForView(_viewStageIndex);
    final isViewingActiveStage = _viewStageIndex == _activeStageIndex;
    final canCompleteStage =
        isViewingActiveStage &&
        !_stageHasOpenMatches(widget.tournament.runStages[_activeStageIndex]);
    final isLastStage =
        _activeStageIndex == widget.tournament.runStages.length - 1;
    final canEditResults = isViewingActiveStage;

    return Scaffold(
      appBar: AppBar(title: Text(widget.tournament.name)),
      body: SafeArea(
        child: Column(
          children: [
            _StageProgressBar(
              stages: widget.tournament.runStages,
              activeStageIndex: _viewStageIndex,
              completedStageIndexes: _completedStageIndexes,
              onStageSelected: (index) {
                setState(() {
                  _viewStageIndex = index;
                  _isBracketEditMode = false;
                });
              },
            ),
            _StageViewModeSwitch(
              selectedMode: _stageViewMode,
              onModeChanged: (mode) {
                setState(() {
                  _stageViewMode = mode;
                });
              },
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_stageViewMode == StageViewMode.overview) ...[
                    if (activeStage is GroupTournamentRunStage)
                      _GroupStageRunSection(
                        stage: activeStage,
                        standingsFor: _standingsFor,
                        onEditResult: _editResult,
                        canEditResults: canEditResults,
                      )
                    else if (activeStage is KnockoutTournamentRunStage)
                      _KnockoutRunSection(
                        stage: activeStage,
                        qualifyingRank: _requiredRankForRunStage(
                          _viewStageIndex,
                        ),
                        onEditResult: _editResult,
                        canEditResults: canEditResults,
                        isEditMode: _isBracketEditMode && canEditResults,
                        canEditBracket:
                            canEditResults && _canEditKnockoutBracket(activeStage),
                        onEditModeChanged: (enabled) {
                          setState(() {
                            _isBracketEditMode = enabled;
                          });
                        },
                        onSwapSlot: (fromSlotIndex, toSlotIndex) {
                          _swapKnockoutRunSlots(
                            activeStage,
                            fromSlotIndex,
                            toSlotIndex,
                          );
                        },
                      ),
                  ] else
                    _StagePlayOrderSection(
                      stage: activeStage,
                      matches: _matchesForStage(activeStage),
                      onEditResult: _editResult,
                      canEditResults: canEditResults,
                    ),
                ],
              ),
            ),
            _StageFooter(
              canCompleteStage: canCompleteStage,
              isLastStage: isLastStage,
              isViewingActiveStage: isViewingActiveStage,
              activeStageName: widget.tournament.runStages[_activeStageIndex].name,
              onCompleteStage: _completeCurrentStage,
              onFinishEarly: _finishCurrentStageEarly,
            ),
          ],
        ),
      ),
    );
  }
}

class _StageProgressBar extends StatelessWidget {
  const _StageProgressBar({
    required this.stages,
    required this.activeStageIndex,
    required this.completedStageIndexes,
    required this.onStageSelected,
  });

  final List<TournamentRunStage> stages;
  final int activeStageIndex;
  final Set<int> completedStageIndexes;
  final ValueChanged<int> onStageSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            for (var index = 0; index < stages.length; index++) ...[
              _StageProgressChip(
                label: stages[index].name,
                number: index + 1,
                isActive: index == activeStageIndex,
                isComplete: completedStageIndexes.contains(index),
                onTap: () => onStageSelected(index),
              ),
              if (index < stages.length - 1)
                Container(
                  width: 28,
                  height: 1,
                  color: colorScheme.outlineVariant,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StageProgressChip extends StatelessWidget {
  const _StageProgressChip({
    required this.label,
    required this.number,
    required this.isActive,
    required this.isComplete,
    required this.onTap,
  });

  final String label;
  final int number;
  final bool isActive;
  final bool isComplete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isActive
        ? colorScheme.primaryContainer
        : colorScheme.surface;
    final borderColor = isActive
        ? colorScheme.primary
        : colorScheme.outlineVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: isComplete
                  ? colorScheme.primary
                  : colorScheme.surface,
              child: Icon(
                isComplete ? Icons.check : Icons.flag_outlined,
                size: 15,
                color: isComplete ? colorScheme.onPrimary : colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text('$number. $label'),
          ],
        ),
      ),
    );
  }
}

enum StageViewMode { overview, playOrder }

class _StageViewModeSwitch extends StatelessWidget {
  const _StageViewModeSwitch({
    required this.selectedMode,
    required this.onModeChanged,
  });

  final StageViewMode selectedMode;
  final ValueChanged<StageViewMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SegmentedButton<StageViewMode>(
        segments: const [
          ButtonSegment(
            value: StageViewMode.overview,
            icon: Icon(Icons.view_agenda_outlined),
            label: Text('Übersicht'),
          ),
          ButtonSegment(
            value: StageViewMode.playOrder,
            icon: Icon(Icons.format_list_numbered),
            label: Text('Spielansicht'),
          ),
        ],
        selected: {selectedMode},
        onSelectionChanged: (selection) => onModeChanged(selection.first),
      ),
    );
  }
}

class _StagePlayOrderSection extends StatelessWidget {
  const _StagePlayOrderSection({
    required this.stage,
    required this.matches,
    required this.onEditResult,
    required this.canEditResults,
  });

  final TournamentRunStage stage;
  final List<GroupMatch> matches;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResults;

  @override
  Widget build(BuildContext context) {
    final rounds = <int, List<GroupMatch>>{};
    for (final match in matches) {
      rounds.putIfAbsent(match.round, () => []).add(match);
    }
    final groupLabels = _groupLabelsByMatch();

    return _StageSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            stage.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Spielreihenfolge',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (matches.isEmpty)
            const Text('Keine Spiele in dieser Etappe.')
          else
            for (final round in rounds.keys.toList()..sort()) ...[
              _RoundHeader(round: round),
              for (final match in rounds[round]!)
                _MatchResultTile(
                  match: match,
                  onEditResult: onEditResult,
                  canEditResult: canEditResults,
                  originLabel: groupLabels[match],
                  leadingLabel: match.isDecider ? match.label : null,
                ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Map<GroupMatch, String> _groupLabelsByMatch() {
    final currentStage = stage;
    if (currentStage is! GroupTournamentRunStage) {
      return const {};
    }

    return {
      for (final group in currentStage.groups)
        for (final match in group.matches) match: group.name,
    };
  }
}

class _RoundHeader extends StatelessWidget {
  const _RoundHeader({required this.round});

  final int round;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.repeat_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Runde $round',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _StageFooter extends StatelessWidget {
  const _StageFooter({
    required this.canCompleteStage,
    required this.isLastStage,
    required this.isViewingActiveStage,
    required this.activeStageName,
    required this.onCompleteStage,
    required this.onFinishEarly,
  });

  final bool canCompleteStage;
  final bool isLastStage;
  final bool isViewingActiveStage;
  final String activeStageName;
  final VoidCallback onCompleteStage;
  final VoidCallback onFinishEarly;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              !isViewingActiveStage
                  ? 'Vorschau: Ergebnisse und Abschluss sind nur in der aktuellen Etappe "$activeStageName" moeglich.'
                  : canCompleteStage
                  ? 'Alle Ergebnisse dieser Etappe sind eingetragen.'
                  : 'Trage alle Ergebnisse ein, um die Etappe abzuschliessen.',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: isViewingActiveStage && !canCompleteStage
                      ? onFinishEarly
                      : null,
                  icon: const Icon(Icons.block_outlined),
                  label: const Text('Etappe vorzeitig beenden'),
                ),
                FilledButton.icon(
                  onPressed: canCompleteStage && isViewingActiveStage
                      ? onCompleteStage
                      : null,
                  icon: Icon(
                    isLastStage
                        ? Icons.check_circle_outline
                        : Icons.arrow_forward,
                  ),
                  label: Text(
                    isLastStage
                        ? 'Turnier abschliessen'
                        : 'Etappe abschliessen',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MatchResult {
  const MatchResult({
    required this.homeLegs,
    required this.awayLegs,
    this.isAnnulled = false,
  });

  const MatchResult.annulled()
    : homeLegs = null,
      awayLegs = null,
      isAnnulled = true;

  final int? homeLegs;
  final int? awayLegs;
  final bool isAnnulled;
}

class _GroupStageRunSection extends StatelessWidget {
  const _GroupStageRunSection({
    required this.stage,
    required this.standingsFor,
    required this.onEditResult,
    required this.canEditResults,
  });

  final GroupTournamentRunStage stage;
  final List<PlayerStanding> Function(
    TournamentGroup group,
    List<String> tieBreakers,
  )
  standingsFor;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResults;

  @override
  Widget build(BuildContext context) {
    final standingsByGroup = {
      for (final group in stage.groups)
        if (group.playType == 'round_robin')
          group: standingsFor(group, stage.tieBreakers),
    };

    return _StageSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            stage.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < stage.groups.length; index++)
            if (stage.groups[index].playType == 'mini_knockout')
              _MiniKnockoutGroupRunSection(
                group: stage.groups[index],
                qualifyingRank: _requiredRankForMiniGroup(stage, index),
                onEditResult: onEditResult,
                canEditResults: canEditResults,
              )
            else
              _GroupRunSection(
                group: stage.groups[index],
                groupNumber: index + 1,
                qualificationPlan: stage.qualificationPlan,
                tieBreakers: stage.tieBreakers,
                standings: standingsByGroup[stage.groups[index]]!,
                onEditResult: onEditResult,
                canEditResults: canEditResults,
              ),
          if (stage.qualificationPlan != null &&
              stage.qualificationPlan!.extraCount > 0 &&
              stage.groups.every((group) => group.playType == 'round_robin')) ...[
            const SizedBox(height: 4),
            _BestOfComparisonTable(
              stage: stage,
              standingsByGroup: standingsByGroup,
            ),
          ],
        ],
      ),
    );
  }

  int _requiredRankForMiniGroup(GroupTournamentRunStage stage, int groupIndex) {
    final plan = stage.qualificationPlan;
    if (plan == null) {
      return 1;
    }

    final fixedForGroup = groupIndex < plan.fixedByGroup.length
        ? plan.fixedByGroup[groupIndex]
        : plan.fixedPerGroup;
    final groupNumber = groupIndex + 1;
    final extraRank = plan.extraGroups.contains(groupNumber)
        ? plan.extraRank
        : 0;
    final requiredRank = fixedForGroup > extraRank ? fixedForGroup : extraRank;
    return requiredRank < 1 ? 1 : requiredRank;
  }
}

class _MiniKnockoutGroupRunSection extends StatelessWidget {
  const _MiniKnockoutGroupRunSection({
    required this.group,
    required this.qualifyingRank,
    required this.onEditResult,
    required this.canEditResults,
  });

  final TournamentGroup group;
  final int qualifyingRank;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResults;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bracketStage = KnockoutTournamentRunStage(
      name: group.name,
      rounds: group.knockoutRounds,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            group.name,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text('Mini-KO-Runde', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (group.knockoutRounds.isEmpty)
            const Text('Keine Paarungen in dieser Gruppe.')
          else
            _KnockoutBracketView(
              stage: bracketStage,
              qualifyingRank: qualifyingRank,
              onEditResult: onEditResult,
              canEditResults: canEditResults,
            ),
          if (group.placementMatches.isNotEmpty) ...[
            const SizedBox(height: 14),
            _PlacementMatchesSection(
              matches: group.placementMatches,
              qualifyingRank: qualifyingRank,
              onEditResult: onEditResult,
              canEditResults: canEditResults,
            ),
          ],
        ],
      ),
    );
  }
}

class _BestOfComparisonTable extends StatelessWidget {
  const _BestOfComparisonTable({
    required this.stage,
    required this.standingsByGroup,
  });

  final GroupTournamentRunStage stage;
  final Map<TournamentGroup, List<PlayerStanding>> standingsByGroup;

  int _compareCandidates(BestOfCandidate a, BestOfCandidate b) {
    for (final tieBreaker in stage.tieBreakers) {
      final comparison = switch (tieBreaker) {
        'points' => b.standing.points.compareTo(a.standing.points),
        'legDifference' => b.standing.legDifference.compareTo(
          a.standing.legDifference,
        ),
        'legsFor' => b.standing.legsFor.compareTo(a.standing.legsFor),
        _ => 0,
      };

      if (comparison != 0) {
        return comparison;
      }
    }

    final groupCompare = a.groupNumber.compareTo(b.groupNumber);
    if (groupCompare != 0) {
      return groupCompare;
    }
    return a.standing.player.name.compareTo(b.standing.player.name);
  }

  bool _allCandidateGroupsComplete(List<BestOfCandidate> candidates) {
    return candidates.every((candidate) {
      final group = stage.groups[candidate.groupNumber - 1];
      return group.matches.every((match) => match.hasResult);
    });
  }

  @override
  Widget build(BuildContext context) {
    final plan = stage.qualificationPlan;
    if (plan == null || plan.extraCount == 0 || plan.extraGroups.isEmpty) {
      return const SizedBox.shrink();
    }

    final candidates = <BestOfCandidate>[];
    for (var groupIndex = 0; groupIndex < stage.groups.length; groupIndex++) {
      final groupNumber = groupIndex + 1;
      if (!plan.extraGroups.contains(groupNumber)) {
        continue;
      }

      final standings = standingsByGroup[stage.groups[groupIndex]] ?? const [];
      final candidateIndex = plan.extraRank - 1;
      if (candidateIndex >= 0 && candidateIndex < standings.length) {
        candidates.add(
          BestOfCandidate(
            groupName: stage.groups[groupIndex].name,
            groupNumber: groupNumber,
            place: plan.extraRank,
            standing: standings[candidateIndex],
          ),
        );
      }
    }

    candidates.sort(_compareCandidates);
    final allComplete = _allCandidateGroupsComplete(candidates);
    final qualifiedColor = allComplete
        ? const Color(0xFF0B6B45)
        : const Color(0xFFC8F7DC);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Beste ${plan.extraCount} der ${plan.extraRank}. Plaetze',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Vergleich aus ${_formatGroups(plan.extraGroups)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 34,
              dataRowMinHeight: 38,
              dataRowMaxHeight: 42,
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Gruppe')),
                DataColumn(label: Text('Spieler')),
                DataColumn(label: Text('Pkt')),
                DataColumn(label: Text('Legs')),
                DataColumn(label: Text('Diff')),
              ],
              rows: [
                for (var index = 0; index < candidates.length; index++)
                  DataRow(
                    color: WidgetStateProperty.resolveWith((states) {
                      return index < plan.extraCount ? qualifiedColor : null;
                    }),
                    cells: [
                      DataCell(Text('${index + 1}')),
                      DataCell(Text(candidates[index].groupName)),
                      DataCell(Text(candidates[index].standing.player.name)),
                      DataCell(Text('${candidates[index].standing.points}')),
                      DataCell(
                        Text(
                          '${candidates[index].standing.legsFor}:'
                          '${candidates[index].standing.legsAgainst}',
                        ),
                      ),
                      DataCell(
                        Text('${candidates[index].standing.legDifference}'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatGroups(List<int> groups) {
    if (groups.length == 1) {
      return groupLabel(groups.first);
    }

    return groups.map(groupLabel).join(', ');
  }
}

class _KnockoutRunSection extends StatelessWidget {
  const _KnockoutRunSection({
    required this.stage,
    required this.qualifyingRank,
    required this.onEditResult,
    required this.canEditResults,
    required this.isEditMode,
    required this.canEditBracket,
    required this.onEditModeChanged,
    required this.onSwapSlot,
  });

  final KnockoutTournamentRunStage stage;
  final int qualifyingRank;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResults;
  final bool isEditMode;
  final bool canEditBracket;
  final ValueChanged<bool> onEditModeChanged;
  final void Function(int fromSlotIndex, int toSlotIndex) onSwapSlot;

  @override
  Widget build(BuildContext context) {
    return _StageSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            stage.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Turnierbaum',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: canEditBracket
                  ? () => onEditModeChanged(!isEditMode)
                  : null,
              icon: Icon(
                isEditMode ? Icons.check_circle_outline : Icons.open_with,
              ),
              label: Text(
                isEditMode
                    ? 'Bearbeitung beenden'
                    : 'Positionen bearbeiten',
              ),
            ),
          ),
          if (!canEditBracket) ...[
            const SizedBox(height: 8),
            Text(
              canEditResults
                  ? 'Positionen koennen nur geaendert werden, solange in dieser K.-o.-Etappe noch kein Ergebnis eingetragen ist.'
                  : 'Positionen koennen nur in der aktuellen Etappe bearbeitet werden.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else if (isEditMode) ...[
            const SizedBox(height: 8),
            Text(
              'Ziehe Spieler in Runde 1 auf einen anderen Platz oder ein Freilos.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          if (stage.rounds.isEmpty)
            const Text('Keine Paarungen in dieser Etappe.')
          else
            _KnockoutBracketView(
              stage: stage,
              qualifyingRank: qualifyingRank,
              onEditResult: onEditResult,
              canEditResults: canEditResults,
              isEditMode: isEditMode && canEditBracket,
              onSwapSlot: onSwapSlot,
            ),
          if (stage.placementMatches.isNotEmpty) ...[
            const SizedBox(height: 14),
            _PlacementMatchesSection(
              matches: stage.placementMatches,
              qualifyingRank: qualifyingRank,
              onEditResult: onEditResult,
              canEditResults: canEditResults,
            ),
          ],
        ],
      ),
    );
  }

}

class _PlacementMatchesSection extends StatelessWidget {
  const _PlacementMatchesSection({
    required this.matches,
    required this.qualifyingRank,
    required this.onEditResult,
    required this.canEditResults,
  });

  final List<GroupMatch> matches;
  final int qualifyingRank;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResults;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Platzierungsspiele',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final match in matches)
          _MatchResultTile(
            match: match,
            onEditResult: onEditResult,
            canEditResult: canEditResults,
            leadingLabel: match.label,
            qualificationLabel: _placementQualificationLabel(
              match.label,
              qualifyingRank,
            ),
          ),
      ],
    );
  }

  String? _placementQualificationLabel(String? label, int qualifyingRank) {
    if (label == 'Spiel um Platz 3') {
      if (qualifyingRank >= 4) return 'Platz 3-4 weiter';
      if (qualifyingRank >= 3) return 'Sieger weiter';
    }
    if (label?.startsWith('Platz 5 Halbfinale') ?? false) {
      if (qualifyingRank >= 8) return 'Platz 5-8 weiter';
      if (qualifyingRank >= 5) return 'relevant fuer Platz 5';
    }
    if (label == 'Spiel um Platz 5') {
      if (qualifyingRank >= 6) return 'Platz 5-6 weiter';
      if (qualifyingRank >= 5) return 'Sieger weiter';
    }
    if (label == 'Spiel um Platz 7') {
      if (qualifyingRank >= 8) return 'Platz 7-8 weiter';
      if (qualifyingRank >= 7) return 'Sieger weiter';
    }
    return null;
  }
}

class _KnockoutBracketView extends StatelessWidget {
  const _KnockoutBracketView({
    required this.stage,
    required this.qualifyingRank,
    required this.onEditResult,
    required this.canEditResults,
    this.isEditMode = false,
    this.onSwapSlot,
  });

  final KnockoutTournamentRunStage stage;
  final int qualifyingRank;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResults;
  final bool isEditMode;
  final void Function(int fromSlotIndex, int toSlotIndex)? onSwapSlot;

  @override
  Widget build(BuildContext context) {
    return _BracketTreeLayout(
      totalRounds: stage.rounds.length,
      columnWidth: 260,
      cardHeight: 204,
      firstRoundGap: 12,
      roundTitles: [
        for (var index = 0; index < stage.rounds.length; index++)
          _bracketRoundTitle(index, stage.rounds.length),
      ],
      roundCards: [
        for (var roundIndex = 0; roundIndex < stage.rounds.length; roundIndex++)
          [
            for (
              var matchIndex = 0;
              matchIndex < stage.rounds[roundIndex].length;
              matchIndex++
            )
              _KnockoutBracketMatchCard(
                match: stage.rounds[roundIndex][matchIndex],
                matchNumber: matchIndex + 1,
                roundIndex: roundIndex,
                matchIndex: matchIndex,
                totalRounds: stage.rounds.length,
                qualifyingRank: qualifyingRank,
                onEditResult: onEditResult,
                canEditResult: canEditResults,
                isEditMode: isEditMode,
                onSwapSlot: onSwapSlot,
              ),
          ],
      ],
    );
  }
}

String _bracketRoundTitle(int roundIndex, int totalRounds) {
  if (roundIndex == totalRounds - 1) {
    return 'Finale';
  }
  if (roundIndex == totalRounds - 2) {
    return 'Halbfinale';
  }
  return 'Runde ${roundIndex + 1}';
}

class _BracketTreeLayout extends StatelessWidget {
  const _BracketTreeLayout({
    required this.totalRounds,
    required this.roundTitles,
    required this.roundCards,
    required this.columnWidth,
    required this.cardHeight,
    required this.firstRoundGap,
  });

  static const double _headerHeight = 34;
  static const double _headerGap = 10;
  static const double _connectorWidth = 34;

  final int totalRounds;
  final List<String> roundTitles;
  final List<List<Widget>> roundCards;
  final double columnWidth;
  final double cardHeight;
  final double firstRoundGap;

  double _centerY(int roundIndex, int matchIndex) {
    final firstPitch = cardHeight + firstRoundGap;
    final span = 1 << roundIndex;
    final firstMatchIndex = matchIndex * span;
    final lastMatchIndex = firstMatchIndex + span - 1;
    final firstCenter =
        _headerHeight + _headerGap + firstMatchIndex * firstPitch + cardHeight / 2;
    final lastCenter =
        _headerHeight + _headerGap + lastMatchIndex * firstPitch + cardHeight / 2;
    return (firstCenter + lastCenter) / 2;
  }

  @override
  Widget build(BuildContext context) {
    if (totalRounds == 0 || roundCards.isEmpty) {
      return const SizedBox.shrink();
    }

    final firstRoundCount = roundCards.first.length;
    final height = _headerHeight +
        _headerGap +
        firstRoundCount * cardHeight +
        (firstRoundCount - 1) * firstRoundGap;
    final width =
        totalRounds * columnWidth + (totalRounds - 1) * _connectorWidth;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BracketConnectorPainter(
                  totalRounds: totalRounds,
                  roundCards: roundCards,
                  columnWidth: columnWidth,
                  connectorWidth: _connectorWidth,
                  cardHeight: cardHeight,
                  firstRoundGap: firstRoundGap,
                  headerHeight: _headerHeight,
                  headerGap: _headerGap,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            for (var roundIndex = 0; roundIndex < totalRounds; roundIndex++)
              Positioned(
                left: roundIndex * (columnWidth + _connectorWidth),
                top: 0,
                width: columnWidth,
                height: _headerHeight,
                child: _BracketRoundTitle(title: roundTitles[roundIndex]),
              ),
            for (var roundIndex = 0; roundIndex < roundCards.length; roundIndex++)
              for (
                var matchIndex = 0;
                matchIndex < roundCards[roundIndex].length;
                matchIndex++
              )
                Positioned(
                  left: roundIndex * (columnWidth + _connectorWidth),
                  top: _centerY(roundIndex, matchIndex) - cardHeight / 2,
                  width: columnWidth,
                  height: cardHeight,
                  child: roundCards[roundIndex][matchIndex],
                ),
          ],
        ),
      ),
    );
  }
}

class _BracketRoundTitle extends StatelessWidget {
  const _BracketRoundTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _BracketConnectorPainter extends CustomPainter {
  const _BracketConnectorPainter({
    required this.totalRounds,
    required this.roundCards,
    required this.columnWidth,
    required this.connectorWidth,
    required this.cardHeight,
    required this.firstRoundGap,
    required this.headerHeight,
    required this.headerGap,
    required this.color,
  });

  final int totalRounds;
  final List<List<Widget>> roundCards;
  final double columnWidth;
  final double connectorWidth;
  final double cardHeight;
  final double firstRoundGap;
  final double headerHeight;
  final double headerGap;
  final Color color;

  double _centerY(int roundIndex, int matchIndex) {
    final firstPitch = cardHeight + firstRoundGap;
    final span = 1 << roundIndex;
    final firstMatchIndex = matchIndex * span;
    final lastMatchIndex = firstMatchIndex + span - 1;
    final firstCenter =
        headerHeight + headerGap + firstMatchIndex * firstPitch + cardHeight / 2;
    final lastCenter =
        headerHeight + headerGap + lastMatchIndex * firstPitch + cardHeight / 2;
    return (firstCenter + lastCenter) / 2;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (var roundIndex = 0; roundIndex < totalRounds - 1; roundIndex++) {
      for (
        var matchIndex = 0;
        matchIndex < roundCards[roundIndex].length;
        matchIndex++
      ) {
        final nextMatchIndex = matchIndex ~/ 2;
        if (nextMatchIndex >= roundCards[roundIndex + 1].length) {
          continue;
        }

        final startX = roundIndex * (columnWidth + connectorWidth) + columnWidth;
        final endX = (roundIndex + 1) * (columnWidth + connectorWidth);
        final midX = startX + connectorWidth / 2;
        final startY = _centerY(roundIndex, matchIndex);
        final endY = _centerY(roundIndex + 1, nextMatchIndex);

        final path = Path()
          ..moveTo(startX, startY)
          ..lineTo(midX, startY)
          ..lineTo(midX, endY)
          ..lineTo(endX, endY);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BracketConnectorPainter oldDelegate) {
    return oldDelegate.totalRounds != totalRounds ||
        oldDelegate.roundCards != roundCards ||
        oldDelegate.columnWidth != columnWidth ||
        oldDelegate.connectorWidth != connectorWidth ||
        oldDelegate.cardHeight != cardHeight ||
        oldDelegate.firstRoundGap != firstRoundGap ||
        oldDelegate.color != color;
  }
}

class _KnockoutBracketMatchCard extends StatelessWidget {
  const _KnockoutBracketMatchCard({
    required this.match,
    required this.matchNumber,
    required this.roundIndex,
    required this.matchIndex,
    required this.totalRounds,
    required this.qualifyingRank,
    required this.onEditResult,
    required this.canEditResult,
    required this.isEditMode,
    this.onSwapSlot,
  });

  final GroupMatch match;
  final int matchNumber;
  final int roundIndex;
  final int matchIndex;
  final int totalRounds;
  final int qualifyingRank;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResult;
  final bool isEditMode;
  final void Function(int fromSlotIndex, int toSlotIndex)? onSwapSlot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final winner = match.winner;
    final qualificationLabel = _bracketQualificationLabel();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_tree_outlined,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Spiel $matchNumber',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              IconButton.filledTonal(
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                onPressed: canEditResult && match.hasPlayers
                    ? () => onEditResult(match)
                    : null,
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Ergebnis',
              ),
            ],
          ),
          const SizedBox(height: 8),
          _BracketPlayerSlot(
            player: match.homePlayer,
            score: match.homeLegs,
            isWinner: winner != null && winner == match.homePlayer,
            label: match.homePlayer == null && match.allowsBye
                ? 'Freilos'
                : null,
            slotIndex: matchIndex * 2,
            isEditable: isEditMode && roundIndex == 0,
            onSwapSlot: onSwapSlot,
          ),
          const SizedBox(height: 6),
          _BracketPlayerSlot(
            player: match.awayPlayer,
            score: match.awayLegs,
            isWinner: winner != null && winner == match.awayPlayer,
            label: match.awayPlayer == null && match.allowsBye
                ? 'Freilos'
                : null,
            slotIndex: matchIndex * 2 + 1,
            isEditable: isEditMode && roundIndex == 0,
            onSwapSlot: onSwapSlot,
          ),
          if (qualificationLabel != null) ...[
            const SizedBox(height: 8),
            _QualificationMarker(label: qualificationLabel),
          ],
        ],
      ),
    );
  }

  String? _bracketQualificationLabel() {
    if (roundIndex == totalRounds - 1) {
      return qualifyingRank >= 2 ? 'Platz 1-2 weiter' : 'Sieger weiter';
    }

    if (roundIndex == totalRounds - 2) {
      if (qualifyingRank >= 4) return 'Platz 1-4 weiter';
      if (qualifyingRank >= 3) return 'Verlierer spielt Platz 3';
      return 'Sieger weiter';
    }

    if (roundIndex == totalRounds - 3) {
      if (qualifyingRank >= 8) return 'Platz 1-8 weiter';
      if (qualifyingRank >= 5) return 'Verlierer spielt Platz 5';
      return 'Sieger weiter';
    }

    return qualifyingRank > 1 ? 'Sieger weiter' : null;
  }
}

class _BracketPlayerSlot extends StatelessWidget {
  const _BracketPlayerSlot({
    required this.player,
    required this.score,
    required this.isWinner,
    this.label,
    this.slotIndex,
    this.isEditable = false,
    this.onSwapSlot,
  });

  final TournamentPlayer? player;
  final int? score;
  final bool isWinner;
  final String? label;
  final int? slotIndex;
  final bool isEditable;
  final void Function(int fromSlotIndex, int toSlotIndex)? onSwapSlot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOpen = player == null;
    final displayLabel = label ?? player?.name ?? 'offen';

    final baseSlot = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isWinner
            ? colorScheme.primaryContainer
            : isEditable
            ? colorScheme.secondaryContainer.withValues(alpha: 0.35)
            : colorScheme.surfaceContainerLowest,
        border: Border.all(
          color: isWinner
              ? colorScheme.primary
              : isEditable
              ? colorScheme.secondary
              : colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isOpen ? colorScheme.onSurfaceVariant : null,
                fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            score == null ? '-' : '$score',
            style: TextStyle(
              color: isOpen ? colorScheme.onSurfaceVariant : null,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    Widget slot = baseSlot;
    if (isEditable && slotIndex != null) {
      slot = DragTarget<int>(
        onWillAcceptWithDetails: (details) => details.data != slotIndex,
        onAcceptWithDetails: (details) {
          onSwapSlot?.call(details.data, slotIndex!);
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: isHovering
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.22),
                        blurRadius: 8,
                      ),
                    ]
                  : const [],
            ),
            child: baseSlot,
          );
        },
      );
    }

    if (isEditable && player != null && slotIndex != null) {
      return Draggable<int>(
        data: slotIndex!,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(width: 220, child: slot),
        ),
        childWhenDragging: Opacity(opacity: 0.45, child: slot),
        child: slot,
      );
    }

    return slot;
  }
}

class _StageSurface extends StatelessWidget {
  const _StageSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _GroupRunSection extends StatefulWidget {
  const _GroupRunSection({
    required this.group,
    required this.groupNumber,
    required this.qualificationPlan,
    required this.tieBreakers,
    required this.standings,
    required this.onEditResult,
    required this.canEditResults,
  });

  final TournamentGroup group;
  final int groupNumber;
  final QualificationPlan? qualificationPlan;
  final List<String> tieBreakers;
  final List<PlayerStanding> standings;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResults;

  @override
  State<_GroupRunSection> createState() => _GroupRunSectionState();
}

class _GroupRunSectionState extends State<_GroupRunSection> {
  bool _showMatches = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.group.name,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _StandingsTable(
            standings: widget.standings,
            group: widget.group,
            groupNumber: widget.groupNumber,
            qualificationPlan: widget.qualificationPlan,
            tieBreakers: widget.tieBreakers,
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() {
                _showMatches = !_showMatches;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _showMatches
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Spiele',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Chip(label: Text('${widget.group.matches.length}')),
                ],
              ),
            ),
          ),
          if (_showMatches) ...[
            const SizedBox(height: 8),
            for (final match in widget.group.matches)
              _MatchResultTile(
                match: match,
                onEditResult: widget.onEditResult,
                canEditResult: widget.canEditResults,
                leadingLabel: match.isDecider ? match.label : null,
              ),
          ],
        ],
      ),
    );
  }
}

class _MatchResultTile extends StatelessWidget {
  const _MatchResultTile({
    required this.match,
    required this.onEditResult,
    required this.canEditResult,
    this.originLabel,
    this.leadingLabel,
    this.qualificationLabel,
  });

  final GroupMatch match;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResult;
  final String? originLabel;
  final String? leadingLabel;
  final String? qualificationLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: leadingLabel == null ? 74 : 148,
            child: Text(
              leadingLabel ?? 'Runde ${match.round}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(width: 8),
          if (originLabel != null) ...[
            _MatchOriginChip(label: originLabel!),
            const SizedBox(width: 8),
          ],
          if (qualificationLabel != null) ...[
            _QualificationMarker(label: qualificationLabel!),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(match.homePlayer?.name ?? 'offen')),
          _ScoreBadge(
            match: match,
            onTap: canEditResult && match.hasPlayers
                ? () => onEditResult(match)
                : null,
          ),
          Expanded(
            child: Text(
              match.awayPlayer?.name ?? 'offen',
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            onPressed: canEditResult && match.hasPlayers
                ? () => onEditResult(match)
                : null,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Ergebnis',
          ),
        ],
      ),
    );
  }
}

class _QualificationMarker extends StatelessWidget {
  const _QualificationMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFC8F7DC);
    const borderColor = Color(0xFF14965F);
    const textColor = Color(0xFF0B6B45);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MatchOriginChip extends StatelessWidget {
  const _MatchOriginChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 76),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.match, this.onTap});

  final GroupMatch match;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final badge = Container(
      width: match.isAnnulled ? 92 : 64,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: match.isAnnulled
            ? colorScheme.errorContainer
            : match.hasResult
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        match.isAnnulled
            ? 'annulliert'
            : match.hasResult
            ? '${match.homeLegs}:${match.awayLegs}'
            : '-:-',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );

    if (onTap == null) {
      return badge;
    }

    return Tooltip(
      message: 'Ergebnis eingeben',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: badge,
      ),
    );
  }
}

class _StandingsTable extends StatelessWidget {
  const _StandingsTable({
    required this.standings,
    required this.group,
    required this.groupNumber,
    required this.qualificationPlan,
    required this.tieBreakers,
  });

  final List<PlayerStanding> standings;
  final TournamentGroup group;
  final int groupNumber;
  final QualificationPlan? qualificationPlan;
  final List<String> tieBreakers;

  bool get _allMatchesComplete {
    return group.matches.every((match) => match.hasResult);
  }

  bool _isFixedQualificationPlace(int place) {
    final plan = qualificationPlan;
    if (plan == null) {
      return false;
    }

    final fixedForGroup = groupNumber - 1 < plan.fixedByGroup.length
        ? plan.fixedByGroup[groupNumber - 1]
        : plan.fixedPerGroup;
    return place <= fixedForGroup;
  }

  bool _isBestOfCandidatePlace(int place) {
    final plan = qualificationPlan;
    if (plan == null) {
      return false;
    }

    return plan.extraCount > 0 &&
        place == plan.extraRank &&
        plan.extraGroups.contains(groupNumber);
  }

  int _qualificationPlacesInGroup() {
    final plan = qualificationPlan;
    if (plan == null) {
      return 0;
    }

    final fixedForGroup = groupNumber - 1 < plan.fixedByGroup.length
        ? plan.fixedByGroup[groupNumber - 1]
        : plan.fixedPerGroup;
    return fixedForGroup +
        (plan.extraGroups.contains(groupNumber) && plan.extraCount > 0 ? 1 : 0);
  }

  int _remainingMatchesFor(PlayerStanding standing) {
    return group.matches.where((match) {
      if (match.hasResult) {
        return false;
      }

      return match.homePlayer?.name == standing.player.name ||
          match.awayPlayer?.name == standing.player.name;
    }).length;
  }

  bool _isSureQualification(PlayerStanding standing, int place) {
    if (!_isFixedQualificationPlace(place)) {
      return false;
    }

    if (_allMatchesComplete) {
      return true;
    }

    final qualificationPlaces = _qualificationPlacesInGroup();
    if (qualificationPlaces < 1) {
      return false;
    }

    final possibleOvertakers = standings.where((otherStanding) {
      if (otherStanding.player.name == standing.player.name) {
        return false;
      }

      final maxPoints =
          otherStanding.points + (_remainingMatchesFor(otherStanding) * 3);
      if (maxPoints > standing.points) {
        return true;
      }
      if (maxPoints < standing.points) {
        return false;
      }

      return _compareStandingsForTable(otherStanding, standing) < 0;
    }).length;

    return possibleOvertakers < qualificationPlaces;
  }

  int _compareStandingsForTable(PlayerStanding a, PlayerStanding b) {
    for (final tieBreaker in tieBreakers) {
      final comparison = switch (tieBreaker) {
        'points' => b.points.compareTo(a.points),
        'legDifference' => b.legDifference.compareTo(a.legDifference),
        'legsFor' => b.legsFor.compareTo(a.legsFor),
        'headToHead' => _compareHeadToHeadForTable(a, b),
        _ => 0,
      };

      if (comparison != 0) {
        return comparison;
      }
    }

    return a.player.name.compareTo(b.player.name);
  }

  int _compareHeadToHeadForTable(PlayerStanding a, PlayerStanding b) {
    var aPoints = 0;
    var bPoints = 0;
    var aLegs = 0;
    var bLegs = 0;

    for (final match in group.matches.where(
      (match) => match.hasResult && !match.isDecider,
    )) {
      final home = match.homePlayer!;
      final away = match.awayPlayer!;
      final isDirectMatch =
          (home.name == a.player.name && away.name == b.player.name) ||
          (home.name == b.player.name && away.name == a.player.name);
      if (!isDirectMatch) {
        continue;
      }

      final aIsHome = home.name == a.player.name;
      final aMatchLegs = aIsHome ? match.homeLegs! : match.awayLegs!;
      final bMatchLegs = aIsHome ? match.awayLegs! : match.homeLegs!;
      aLegs += aMatchLegs;
      bLegs += bMatchLegs;

      if (aMatchLegs > bMatchLegs) {
        aPoints += 3;
      } else if (bMatchLegs > aMatchLegs) {
        bPoints += 3;
      } else {
        aPoints++;
        bPoints++;
      }
    }

    final pointCompare = bPoints.compareTo(aPoints);
    if (pointCompare != 0) return pointCompare;
    final diffCompare = (bLegs - aLegs).compareTo(aLegs - bLegs);
    if (diffCompare != 0) return diffCompare;
    return bLegs.compareTo(aLegs);
  }

  @override
  Widget build(BuildContext context) {
    final sureColor = const Color(0xFF0B6B45);
    final possibleColor = const Color(0xFFC8F7DC);
    final bestOfColor = const Color(0xFFFFE8A3);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 44,
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('Spieler')),
          DataColumn(label: Text('Sp')),
          DataColumn(label: Text('S')),
          DataColumn(label: Text('U')),
          DataColumn(label: Text('N')),
          DataColumn(label: Text('Legs')),
          DataColumn(label: Text('Diff')),
          DataColumn(label: Text('Pkt')),
        ],
        rows: [
          for (var index = 0; index < standings.length; index++)
            DataRow(
              color: WidgetStateProperty.resolveWith((states) {
                final place = index + 1;
                if (_isFixedQualificationPlace(place)) {
                  return _isSureQualification(standings[index], place)
                      ? sureColor
                      : possibleColor;
                }

                if (_isBestOfCandidatePlace(place)) {
                  return bestOfColor;
                }

                return null;
              }),
              cells: [
                DataCell(
                  _StandingText(
                    '${index + 1}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    standings[index].player.name,
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    '${standings[index].played}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    '${standings[index].wins}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    '${standings[index].draws}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    '${standings[index].losses}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    '${standings[index].legsFor}:${standings[index].legsAgainst}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    '${standings[index].legDifference}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    '${standings[index].points}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StandingText extends StatelessWidget {
  const _StandingText(this.text, {required this.isDark});

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: isDark ? Colors.white : null,
        fontWeight: isDark ? FontWeight.w600 : null,
      ),
    );
  }
}

class _ResultDialog extends StatefulWidget {
  const _ResultDialog({required this.match});

  final GroupMatch match;

  @override
  State<_ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<_ResultDialog> {
  late final TextEditingController _homeLegsController;
  late final TextEditingController _awayLegsController;

  @override
  void initState() {
    super.initState();
    _homeLegsController = TextEditingController(
      text: widget.match.homeLegs?.toString() ?? '',
    );
    _awayLegsController = TextEditingController(
      text: widget.match.awayLegs?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _homeLegsController.dispose();
    _awayLegsController.dispose();
    super.dispose();
  }

  void _save() {
    final homeLegs = int.tryParse(_homeLegsController.text);
    final awayLegs = int.tryParse(_awayLegsController.text);
    if (homeLegs == null || awayLegs == null || homeLegs < 0 || awayLegs < 0) {
      return;
    }
    if (widget.match.isDecider && homeLegs == awayLegs) {
      return;
    }

    Navigator.of(
      context,
    ).pop(MatchResult(homeLegs: homeLegs, awayLegs: awayLegs));
  }

  void _annul() {
    Navigator.of(context).pop(const MatchResult.annulled());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ergebnis eingeben'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.match.homePlayer?.name ?? 'offen'} vs '
            '${widget.match.awayPlayer?.name ?? 'offen'}',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('home-legs-field'),
                  controller: _homeLegsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: widget.match.homePlayer?.name ?? 'offen',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const ValueKey('away-legs-field'),
                  controller: _awayLegsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: widget.match.awayPlayer?.name ?? 'offen',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: _annul,
          icon: const Icon(Icons.block_outlined),
          label: const Text('Spiel annullieren'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _save, child: const Text('Speichern')),
      ],
    );
  }
}

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
        _CompactKnockoutPreviewTree(
          bracketSize: resolvedBracketSize,
          slotOrder: slots,
          participantLabels: participantLabels,
          onSwapSlot: onSwapSlot,
        ),
      ],
    );
  }
}

class _CompactKnockoutPreviewTree extends StatelessWidget {
  const _CompactKnockoutPreviewTree({
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
    final roundSizes = <int>[];
    var matchesInRound = bracketSize ~/ 2;
    while (matchesInRound >= 1) {
      roundSizes.add(matchesInRound);
      matchesInRound ~/= 2;
    }

    return _BracketTreeLayout(
      totalRounds: roundSizes.length,
      columnWidth: 160,
      cardHeight: 108,
      firstRoundGap: 10,
      roundTitles: [
        for (var roundIndex = 0; roundIndex < roundSizes.length; roundIndex++)
          _bracketRoundTitle(roundIndex, roundSizes.length),
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
          if (playType == 'mini_knockout' && playerCount >= 2) ...[
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
    if (stage.type == 'single_knockout') {
      return _knockoutPlayableMatchCount(stage.knockoutParticipantCount ?? 0);
    }

    var totalMatches = 0;
    for (var index = 0; index < stage.groupSizes.length; index++) {
      final repeatCount = _roundRobinRepeatForStage(stage, index);
      totalMatches += _groupPlayTypeForStage(stage, index) == 'mini_knockout'
          ? _knockoutPlayableMatchCount(stage.groupSizes[index])
          : _roundRobinMatchCount(stage.groupSizes[index], repeatCount);
    }

    return totalMatches;
  }

  String _matchCountDetails(TournamentStage stage) {
    return ' - ${_stageMatchCount(stage)} Spiele';
  }

  String _stageDetails(TournamentStage stage) {
    if (stage.type != 'groups' || stage.groupSizes.isEmpty) {
      if (stage.type == 'single_knockout' &&
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
