part of '../../../../tournament_workspace.dart';

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
  final _database = LocalAppDatabase();
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
  bool _isOpeningPlayerPicker = false;

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
    if (_isKnockoutStageType(_selectedStageType)) {
      return _eliminationMatchEstimate(
        _knockoutParticipantCount() ?? 0,
        _lossLimitForStageType(_selectedStageType),
      );
    }

    final groupSizes = _calculateGroupSizes();
    final repeats = _roundRobinRepeatsForGroupSizes(groupSizes);
    final playTypes = _playTypesForGroupSizes(groupSizes);
    final qualificationPlan = _groupQualificationPlan();
    var totalMatches = 0;
    for (var index = 0; index < groupSizes.length; index++) {
      totalMatches += playTypes[index] == 'round_robin'
          ? _roundRobinMatchCount(groupSizes[index], repeats[index])
          : _groupEliminationMatchEstimate(
              groupSizes[index],
              _lossLimitForGroupPlayType(playTypes[index]),
              _requiredRankForCurrentGroup(index, qualificationPlan),
            );
    }

    return totalMatches;
  }

  List<String> _currentStageMatchDetails() {
    if (_isKnockoutStageType(_selectedStageType)) {
      final participants = _knockoutParticipantCount() ?? 0;
      final byeCount = _knockoutByeCount();
      return [
        '$participants Teilnehmer',
        _lossLimitForStageType(_selectedStageType) == 3
            ? '$byeCount automatisch gesetzt'
            : '$byeCount Freilose',
        if (_lossLimitForStageType(_selectedStageType) > 1)
          '${_lossLimitForStageType(_selectedStageType)} Niederlage(n) bis Aus',
      ];
    }

    final groupSizes = _calculateGroupSizes();
    final repeats = _roundRobinRepeatsForGroupSizes(groupSizes);
    final playTypes = _playTypesForGroupSizes(groupSizes);
    final qualificationPlan = _groupQualificationPlan();
    return [
      for (var index = 0; index < groupSizes.length; index++)
        playTypes[index] == 'round_robin'
            ? '${groupLabel(index + 1)} ${_roundRobinMatchCount(groupSizes[index], repeats[index])}'
            : '${groupLabel(index + 1)} ${_groupEliminationMatchEstimate(groupSizes[index], _lossLimitForGroupPlayType(playTypes[index]), _requiredRankForCurrentGroup(index, qualificationPlan))}',
    ];
  }

  int _requiredRankForCurrentGroup(
    int groupIndex,
    QualificationPlan? qualificationPlan,
  ) {
    final plan = qualificationPlan;
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
    if (_effectiveKnockoutSeedingMode() == 'random') {
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

    if (byeCount == 0) {
      final pairs = <List<_KnockoutSeedSource>>[];
      final remaining = List<_KnockoutSeedSource>.from(strengthOrderedSources);

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

      return [
        for (final pair in pairs) ...[pair[0].seed, pair[1].seed],
      ];
    }

    return [
      for (final bracketSeed in _seedOrderForSize(bracketSize))
        bracketSeed <= participantCount
            ? strengthOrderedSources[bracketSeed - 1].seed
            : null,
    ];
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
    final seedingMode = _effectiveKnockoutSeedingMode();
    if (manualOrder != null &&
        _isValidKnockoutSlotOrder(manualOrder, participantCount, bracketSize) &&
        _slotOrderAvoidsByePair(manualOrder) &&
        (seedingMode != 'cross' ||
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
      if (_effectiveKnockoutSeedingMode() == 'random') {
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
      _knockoutSeedingMode = _hasGroupSeedSources() ? mode : 'random';
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

  bool _hasGroupSeedSources() {
    final previousStage = _previousStageForCurrentForm();
    return previousStage != null &&
        previousStage.type == 'groups' &&
        previousStage.groupSizes.isNotEmpty;
  }

  String _effectiveKnockoutSeedingMode() {
    return _hasGroupSeedSources() ? _knockoutSeedingMode : 'random';
  }

  Widget _responsiveFormRow({
    required Widget leading,
    required Widget trailing,
    bool alignTrailingEndOnNarrow = false,
    double breakpoint = 560,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              leading,
              const SizedBox(height: 12),
              alignTrailingEndOnNarrow
                  ? Align(alignment: Alignment.centerRight, child: trailing)
                  : trailing,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: leading),
            const SizedBox(width: 12),
            alignTrailingEndOnNarrow ? trailing : Expanded(child: trailing),
          ],
        );
      },
    );
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
      'double_knockout' => 'Doppel-K.-o.',
      'triple_knockout' => 'Triple-K.-o.',
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

  Future<void> _selectPlayersFromDatabase() async {
    if (_isOpeningPlayerPicker) {
      return;
    }

    setState(() {
      _isOpeningPlayerPicker = true;
    });

    try {
      final profiles = await _database.loadPlayerProfiles();
      if (!mounted) {
        return;
      }
      setState(() {
        _isOpeningPlayerPicker = false;
      });
      final selectedProfiles = await showDialog<List<PlayerProfile>>(
        context: context,
        builder: (context) => _PlayerProfilePickerDialog(
          profiles: profiles,
          selectedProfileIds: {
            for (final player in _players)
              if (player.profileId != null) player.profileId!,
          },
        ),
      );
      if (selectedProfiles == null) {
        return;
      }
      setState(() {
        final guestPlayers = _players
            .where((player) => player.profileId == null)
            .toList(growable: false);
        _players
          ..clear()
          ..addAll(guestPlayers)
          ..addAll(
            selectedProfiles.map(
              (profile) => TournamentPlayer(
                profileId: profile.id,
                name: profile.displayName,
                isGenerated: false,
              ),
            ),
          );
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isOpeningPlayerPicker = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Spieler konnten nicht aus der Datenbank geladen werden.'),
        ),
      );
    }
  }

  void _removePlayer(int index) {
    setState(() {
      _players.removeAt(index);
    });
  }

  Future<void> _renamePlayer(int index) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => RenamePlayerDialog(player: _players[index]),
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
      final inheritedQualificationPlan = _isKnockoutStageType(_selectedStageType)
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
        knockoutParticipantCount: _isKnockoutStageType(_selectedStageType)
            ? _knockoutParticipantCount()
            : null,
        knockoutBracketSize: _isKnockoutStageType(_selectedStageType)
            ? _knockoutBracketSize()
            : null,
        knockoutByeCount: _isKnockoutStageType(_selectedStageType)
            ? _knockoutByeCount()
            : 0,
        knockoutSlotOrder: _isKnockoutStageType(_selectedStageType)
            ? _knockoutSlotOrder()
            : const [],
        knockoutSeedingMode: _isKnockoutStageType(_selectedStageType)
            ? _effectiveKnockoutSeedingMode()
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

      if (_isKnockoutStageType(stage.type)) {
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

    final tournament = const TournamentCreationController().createTournament(
      name: _tournamentNameController.text.trim().isEmpty
          ? 'Neues Turnier'
          : _tournamentNameController.text.trim(),
      players: _players,
      stages: _stages,
      runStages: _buildRunStages(),
    );

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
        final groups = _buildTournamentGroupsForPlayers(
          stage,
          incomingPlayers,
          requiredRankForGroup: _requiredRankForGroup,
        );
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
      } else if (_isKnockoutStageType(stage.type)) {
        final participantCount =
            stage.knockoutParticipantCount ?? incomingPlayers.length;
        final participants = incomingPlayers.take(participantCount).toList();
        final lossLimit = _lossLimitForStageType(stage.type);
        final rounds = lossLimit == 1
            ? _buildKnockoutRounds(
                participants,
                slotOrder: stage.knockoutSlotOrder,
              )
            : lossLimit == 2
                ? _buildDoubleEliminationRounds(
                    participants,
                    slotOrder: stage.knockoutSlotOrder,
                  )
            : _buildTripleEliminationRounds(
                participants,
                slotOrder: stage.knockoutSlotOrder,
              );
        runStages.add(
          KnockoutTournamentRunStage(
            name: stage.name,
            rounds: rounds,
            placementMatches:
                lossLimit == 1 ? _buildPlacementMatches(participants.length, requiredRank) : const [],
            eliminationLossLimit: lossLimit,
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
    return _buildPlacementMatchesForPlayers(participantCount, requiredRank);
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

  List<List<GroupMatch>> _buildDoubleEliminationRounds(
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
    return _buildDoubleEliminationRoundsFromSlots(players, slots);
  }

  List<List<GroupMatch>> _buildTripleEliminationRounds(
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
    return _buildTripleEliminationRoundsFromSlots(players, slots);
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
            _responsiveFormRow(
              alignTrailingEndOnNarrow: true,
              leading: TextField(
                controller: _playerNameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Spielername',
                  prefixIcon: Icon(Icons.person_add_alt_1_outlined),
                ),
                onSubmitted: (_) => _addPlayer(),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filled(
                    onPressed: _addPlayer,
                    icon: const Icon(Icons.add),
                    tooltip: 'Spieler hinzufuegen',
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _isOpeningPlayerPicker
                        ? null
                        : _selectPlayersFromDatabase,
                    icon: _isOpeningPlayerPicker
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.playlist_add_check_outlined),
                    label: const Text('Auswaehlen'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _responsiveFormRow(
              leading: TextField(
                controller: _playerCountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Anzahl',
                ),
              ),
              trailing: OutlinedButton.icon(
                onPressed: _generatePlayers,
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Spieler erzeugen'),
              ),
              breakpoint: 420,
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
            _responsiveFormRow(
              alignTrailingEndOnNarrow: true,
              leading: TextField(
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
              trailing: IconButton.filled(
                onPressed: _saveStage,
                icon: Icon(
                  _editingStageIndex == null ? Icons.add : Icons.check,
                ),
                tooltip: _editingStageIndex == null
                    ? 'Etappe hinzufuegen'
                    : 'Etappe speichern',
              ),
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
                  DropdownMenuItem(
                    value: 'double_knockout',
                    child: Text('Doppel-KO in der Gruppe'),
                  ),
                  DropdownMenuItem(
                    value: 'triple_knockout',
                    child: Text('Triple-KO in der Gruppe'),
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
              _responsiveFormRow(
                leading: TextField(
                  key: const ValueKey('group-count-field'),
                  controller: _groupCountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Gruppen',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                trailing: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: GroupSizePreview(groupSizes: groupSizes),
                ),
                breakpoint: 520,
              ),
              const SizedBox(height: 12),
              GroupPlayTypeSetup(
                groupSizes: groupSizes,
                playTypes: _playTypesForGroupSizes(groupSizes),
                onChanged: _setGroupPlayType,
              ),
              if (_playTypesForGroupSizes(groupSizes).contains(
                'round_robin',
              )) ...[
                const SizedBox(height: 12),
                RoundRobinRepeatsSetup(
                  groupSizes: groupSizes,
                  playTypes: _playTypesForGroupSizes(groupSizes),
                  repeats: _roundRobinRepeatsForGroupSizes(groupSizes),
                  onChangeRepeats: _changeGroupRoundRobinRepeats,
                ),
              ],
              const SizedBox(height: 12),
              StageMatchCountPreview(
                matchCount: _currentStageMatchCount(),
                details: _currentStageMatchDetails(),
              ),
              const SizedBox(height: 12),
              _responsiveFormRow(
                leading: TextField(
                  key: const ValueKey('group-qualifier-count-field'),
                  controller: _groupQualifierCountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Weiter',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                trailing: _GroupQualificationSetup(
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
                breakpoint: 620,
              ),
              const SizedBox(height: 12),
              GroupTieBreakerSetup(
                tieBreakers: _groupTieBreakers,
                onMoveTieBreaker: _moveGroupTieBreaker,
              ),
            ],
            if (_isKnockoutStageType(_selectedStageType)) ...[
              const SizedBox(height: 12),
              _InheritedKnockoutSetup(
                previousStage: _previousStageForCurrentForm(),
                qualificationPlan: inheritedQualificationPlan,
                participantCount: knockoutParticipantCount,
                bracketSize: knockoutBracketSize,
                byeCount: knockoutByeCount,
                eliminationLossLimit: _lossLimitForStageType(
                  _selectedStageType,
                ),
                seedingMode: _effectiveKnockoutSeedingMode(),
                slotOrder: _knockoutSlotOrder(),
                participantLabels: _knockoutParticipantLabels(),
                allowCrossSeed: _hasGroupSeedSources(),
                onSeedingModeChanged: _setKnockoutSeedingMode,
                onSwapSlot: _swapKnockoutSlots,
                onResetSlots: _resetKnockoutSlots,
              ),
            ],
            if (_isKnockoutStageType(_selectedStageType)) ...[
              const SizedBox(height: 12),
              StageMatchCountPreview(
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

class _PlayerProfilePickerDialog extends StatefulWidget {
  const _PlayerProfilePickerDialog({
    required this.profiles,
    required this.selectedProfileIds,
  });

  final List<PlayerProfile> profiles;
  final Set<String> selectedProfileIds;

  @override
  State<_PlayerProfilePickerDialog> createState() =>
      _PlayerProfilePickerDialogState();
}

class _PlayerProfilePickerDialogState
    extends State<_PlayerProfilePickerDialog> {
  late final Set<String> _selectedProfileIds = {
    ...widget.selectedProfileIds,
  };

  void _toggleProfile(String profileId, bool selected) {
    setState(() {
      if (selected) {
        _selectedProfileIds.add(profileId);
      } else {
        _selectedProfileIds.remove(profileId);
      }
    });
  }

  void _submit() {
    Navigator.of(context).pop([
      for (final profile in widget.profiles)
        if (_selectedProfileIds.contains(profile.id)) profile,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Spieler auswaehlen'),
      content: SizedBox(
        width: 460,
        child: widget.profiles.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Noch keine Spielerprofile angelegt.'),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: widget.profiles.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final profile = widget.profiles[index];
                  final selected = _selectedProfileIds.contains(profile.id);
                  final subtitle = [
                    if (profile.city.isNotEmpty) profile.city,
                    if (profile.country.isNotEmpty) profile.country,
                  ].join(', ');
                  return CheckboxListTile(
                    value: selected,
                    onChanged: (value) =>
                        _toggleProfile(profile.id, value ?? false),
                    title: Text(profile.displayName),
                    subtitle: subtitle.isEmpty ? null : Text(subtitle),
                    secondary: CircleAvatar(
                      child: Text(_initialsForProfile(profile.displayName)),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check),
          label: Text('${_selectedProfileIds.length} uebernehmen'),
        ),
      ],
    );
  }

  String _initialsForProfile(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

