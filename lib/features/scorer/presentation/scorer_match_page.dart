import 'widgets/scorer_play_sizing.dart';
import '../../statistics/data/profile_heatmap_repository.dart';
import 'widgets/heatmap_target_picker.dart';
import 'widgets/scorer_play_layout.dart';
import 'widgets/scorer_scoreboard.dart';
import 'monitor/scorer_monitor_page.dart';
import '../application/scorer_monitor_window.dart';
import '../data/scorer_monitor_preferences.dart';
import '../../autoscoring/presentation/widgets/dart_correction_dialog.dart';
import 'checkout_page.dart' show checkoutLabel;
import '../../autoscoring/application/autoscore_audio_controller.dart';
import '../../autoscoring/data/autoscore_audio_output.dart';
import '../../autoscoring/data/autoscore_setup_store.dart';
import '../../autoscoring/presentation/widgets/autoscore_audio_controls.dart';
import '../application/scorer_audio_controller.dart';
import 'widgets/personalized_checkout_routes.dart';
import 'dart:async';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import '../../autoscoring/data/autoscoring_preferences.dart';
import '../../autoscoring/presentation/widgets/scorer_camera_panel.dart';
import 'dart:math';
import '../../statistics/data/player_statistics_repository.dart';
import '../../statistics/domain/saved_scorer_match.dart';
import '../../statistics/data/scorer_heatmap_repository.dart';
import '../../statistics/presentation/heatmap/scorer_heatmap_page.dart';
import 'package:flutter/material.dart';
import '../application/scorer_controller.dart';
import '../data/scorer_draft_storage.dart';
import '../domain/scorer_settings.dart';
import '../domain/scorer_hit.dart';
import '../domain/visit_score_entry.dart';
import '../domain/x01/x01_models.dart';
import 'widgets/score_keypad.dart';
import 'widgets/scorer_statistics_view.dart';
import 'widgets/scorer_leg_sheet.dart';
import 'widgets/scorer_result_view.dart';
import 'widgets/checkout_attempt_dialog.dart';
import '../../remote_control/application/remote_scorer_client.dart';
import '../../remote_control/application/remote_scorer_host.dart';
import '../../remote_control/presentation/remote_host_surface.dart';

class ScorerMatchPage extends StatefulWidget {
  const ScorerMatchPage({
    super.key,
    required this.settings,
    this.accountId,
    this.profilePlayerIndex,
    this.statisticsRepository,
    this.onCompleted,
    this.onExit,
    this.draft,
    this.remote,
    this.startInMonitorMode = false,
    this.audioOutput,
  });
  final ScorerSettings settings;
  final String? accountId;
  final int? profilePlayerIndex;
  final PlayerStatisticsRepository? statisticsRepository;
  final void Function(ScorerController controller)? onCompleted;
  final VoidCallback? onExit;
  final Map<String, dynamic>? draft;
  final RemoteScorerClient? remote;
  final bool startInMonitorMode;
  final AutoscoreAudioOutput? audioOutput;
  @override
  State<ScorerMatchPage> createState() => _ScorerMatchPageState();
}

class _ScorerMatchPageState extends State<ScorerMatchPage> {
  late final ScorerController controller;
  final _monitor = ScorerMonitorWindow();
  bool _openingMonitor = false;
  late bool _deviceMonitor = widget.startInMonitorMode;

  void _showMonitorPage() {
    if (widget.startInMonitorMode) {
      setState(() => _deviceMonitor = true);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScorerMonitorPage(controller: controller),
      ),
    );
  }

  Future<void> _startDefaultMonitor() async {
    if (widget.startInMonitorMode) return;
    try {
      final mode = await ScorerMonitorPreferences().load();
      if (!mounted || controller.isComplete) return;
      if (mode == ScorerMonitorStart.inApp) _showMonitorPage();
      if (mode == ScorerMonitorStart.window) {
        final platform = Theme.of(context).platform;
        if (platform == TargetPlatform.windows ||
            platform == TargetPlatform.macOS ||
            platform == TargetPlatform.linux) {
          await _openMonitorWindow();
        } else {
          _showMonitorPage();
        }
      }
    } catch (_) {
      // A preference read must never prevent scoring.
    }
  }

  Future<void> _chooseMonitor() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Monitor-Modus'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'page'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Nur Punkte in der App anzeigen'),
            ),
          ),
          if ([
            TargetPlatform.windows,
            TargetPlatform.macOS,
            TargetPlatform.linux,
          ].contains(Theme.of(context).platform))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'window'),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Anzeigefenster für zweiten Monitor öffnen'),
              ),
            ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'page') _showMonitorPage();
    if (choice == 'window') await _openMonitorWindow();
  }

  Future<void> _openMonitorWindow() async {
    if (_openingMonitor) return;
    _openingMonitor = true;
    try {
      await _monitor.open(controller);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Anzeigefenster konnte nicht geöffnet werden. Bitte die Punkteanzeige in der App verwenden.',
            ),
          ),
        );
      }
    } finally {
      _openingMonitor = false;
    }
  }

  final _cameraPanelKey = GlobalKey();
  late final _audio = AutoscoreAudioController(
    output: widget.audioOutput,
    setupStore: AutoscoreSetupStore.instance,
  );
  late final ScorerAudioController _scorerAudio;
  RemoteScorerHost? _remoteHost;
  bool get _isRemote => widget.remote != null;
  bool get _inputReady =>
      !_isRemote ||
      (widget.remote!.ready &&
          widget.remote!.state?['resultFinalized'] != true);
  bool _cameraAvailable = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isRemote || _remoteHost != null) return;
    _remoteHost = context
        .getInheritedWidgetOfExactType<RemoteHostScope>()
        ?.controller
        .scorer;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _remoteHost == null) return;
      _remoteHost!.attach(controller, _sessionId);
      _remoteHost!.cameraAction = (action) async {
        if (!mounted) return;
        switch (action) {
          case 'cameraOpen':
            await _openAutoscoring();
          case 'cameraClose':
            _closeCamera();
          case 'cameraConfirm':
            _confirmCameraVisit(const []);
        }
      };
      _publishCamera();
    });
  }

  void _publishCamera() {
    if (_remoteHost?.owns(controller) != true) return;
    _remoteHost?.cameraState(
      available: _cameraAvailable,
      open: _cameraOpen,
      pending: _cameraPending,
      darts: _cameraBase == null
          ? const []
          : [
              for (final action in controller.exportActions().skip(
                _cameraBase!.length,
              ))
                if (action['type'] == 'dart') action['label'] as String,
            ],
    );
  }

  void _undo() {
    if (!_inputReady) return;
    if (_isRemote) {
      unawaited(widget.remote!.command('undo'));
    } else {
      controller.undo();
    }
  }

  final _scoreKeypadKey = GlobalKey();
  Timer? timer;
  bool _bustPending = false;
  late final _statisticsRepository =
      widget.statisticsRepository ?? PlayerStatisticsRepository();
  late final _playedAt = widget.draft == null
      ? DateTime.now()
      : DateTime.parse(widget.draft!['playedAt'] as String);
  late final String _sessionId =
      widget.draft?['sessionId'] as String? ??
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
  final _draftStorage = ScorerDraftStorage();
  Future<void> _saving = Future.value();
  Future<void> _heatmapSaving = Future.value();
  String? _saveError;
  String? _heatmapError;
  bool _hadHeatmap = false;
  final _profileHeatmaps = ProfileHeatmapRepository();

  void _persistHeatmap() {
    if (controller.hits.isEmpty && !_hadHeatmap) return;
    _hadHeatmap = true;
    final session = ScorerHeatmapSession(
      id: _sessionId,
      date: _playedAt,
      names: [for (final p in widget.settings.participants) p.name],
      hits: controller.hits,
      complete: controller.isComplete,
    );
    _heatmapSaving = () async {
      try {
        await ScorerHeatmapRepository().save(session);
        if (widget.accountId != null && widget.profilePlayerIndex != null) {
          await _profileHeatmaps.save(
            widget.accountId!,
            session,
            widget.profilePlayerIndex!,
          );
        }
        if (mounted) setState(() => _heatmapError = null);
      } catch (_) {
        if (mounted) {
          setState(
            () => _heatmapError =
                'Heatmap konnte nicht gespeichert werden. Bitte erneut versuchen.',
          );
        }
      }
    }();
  }

  bool _hadWinner = false;
  bool _mayLeave = false;
  bool _leaving = false;

  void _persistStatistics() {
    if (_isRemote) return;
    _persistHeatmap();
    final id = widget.accountId;
    final index = widget.profilePlayerIndex;
    if (id == null || index == null) return;
    final settings = widget.settings;
    // Team totals must not be saved as an individual's personal statistics.
    if (settings.participants[index].isTeam ||
        settings.participants[index].bot != null) {
      return;
    }
    final snapshot = SavedScorerMatch(
      id: _sessionId,
      accountId: id,
      playedAt: _playedAt,
      playerIndex: index,
      names: [for (final p in settings.participants) p.name],
      startScores: [
        for (final p in settings.participants)
          p.startScore ?? settings.startScore,
      ],
      standard501Rules:
          settings.startRequirement == StartRequirement.straightIn &&
          settings.checkoutRequirement == CheckoutRequirement.doubleOut,
      doubleOut: settings.checkoutRequirement == CheckoutRequirement.doubleOut,
      visits: controller.statisticsVisits
          .where((v) => settings.participants[v.player].bot == null)
          .toList(),
      pendingDarts: controller.activePlayer == index
          ? controller.visit.length
          : 0,
      winner: controller.winner,
      isDraw: controller.isDraw,
    );
    final shouldSync = controller.isComplete || _hadWinner;
    _hadWinner = controller.isComplete;
    _saving = _saving.then((_) async {
      try {
        await _statisticsRepository.save(snapshot);
        if (mounted) setState(() => _saveError = null);
        if (shouldSync) unawaited(_statisticsRepository.synchronize(id));
      } catch (_) {
        if (mounted) {
          setState(
            () => _saveError =
                'Statistiken konnten nicht gespeichert werden. Bitte erneut versuchen.',
          );
        }
      }
    });
  }

  Future<void> _leave() async {
    if (_isRemote) {
      widget.onExit?.call();
      return;
    }
    if (_leaving) return;
    setState(() => _leaving = true);
    timer?.cancel();
    // Device-managed matches have their own session lifecycle.
    if (widget.onExit == null) {
      bool? save = false;
      if (!controller.isComplete) {
        save = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: const Text('Spiel zwischenspeichern?'),
            content: const Text(
              'Du kannst das Spiel später im Scorer fortsetzen. '
              'Ein vorhandener gespeicherter Spielstand wird beim Speichern ersetzt.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Weiterspielen'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Ohne Speichern verlassen'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Speichern und verlassen'),
              ),
            ],
          ),
        );
      }
      if (!mounted) return;
      if (save == null) {
        setState(() => _leaving = false);
        _scheduleBot();
        return;
      }
      try {
        if (save) {
          await _draftStorage.save(
            widget.accountId,
            ScorerDraftStorage.checkpoint(
              controller,
              sessionId: _sessionId,
              playedAt: _playedAt,
              profilePlayerIndex: widget.profilePlayerIndex,
            ),
          );
        } else {
          await _draftStorage.removeSession(widget.accountId, _sessionId);
        }
      } catch (_) {
        if (!mounted) return;
        setState(() => _leaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Spielstand konnte nicht gespeichert oder entfernt werden. Bitte erneut versuchen.',
            ),
          ),
        );
        _scheduleBot();
        return;
      }
    }
    _persistStatistics();
    await _saving;
    await _heatmapSaving;
    if (!mounted) return;
    if (_saveError != null || _heatmapError != null) {
      setState(() => _leaving = false);
      _scheduleBot();
      return;
    }
    setState(() => _mayLeave = true);
    if (widget.accountId != null) {
      unawaited(_statisticsRepository.synchronize(widget.accountId!));
      unawaited(_profileHeatmaps.synchronize(widget.accountId!));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

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

  Future<void> _showAudio() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: AutoscoreAudioControls(controller: _audio, matchScorer: true),
      ),
    ),
  );

  bool _automaticCameraPending = false;
  bool _localCameraOpen = false;
  bool _showCameraDetails = false;
  bool get _cameraOpen => _isRemote
      ? (widget.remote!.state?['cameraOpen'] == true)
      : _localCameraOpen;

  Future<void> _checkAutomaticCamera() async {
    if (_isRemote) return;
    try {
      final enabled = await AutoscoringPreferences().load();
      if (!mounted || controller.isComplete) return;
      final cameras = await CameraPlatform.instance.availableCameras();
      if (!mounted) return;
      _cameraAvailable = cameras.length >= 3;
      _publishCamera();
      if (!enabled || !_cameraAvailable) return;
      _automaticCameraPending = true;
      _tryAutomaticCamera();
    } catch (_) {
      // Unavailable camera plugins or permissions leave manual scoring usable.
    }
  }

  void _tryAutomaticCamera() {
    if (!_automaticCameraPending ||
        _cameraOpen ||
        _leaving ||
        controller.isBotTurn ||
        controller.isComplete) {
      return;
    }
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _automaticCameraPending = false;
    unawaited(_openAutoscoring(autoConnect: true));
  }

  Future<void> _openAutoscoring({bool autoConnect = false}) async {
    if (_isRemote) {
      await widget.remote!.command('cameraOpen');
      return;
    }
    if (controller.isBotTurn || controller.isComplete || _cameraOpen) return;
    setState(() => _localCameraOpen = true);
    _publishCamera();
  }

  List<Map<String, dynamic>>? _cameraBase;
  List<bool> _cameraAttempts = [];
  List<DartLocation?> _cameraLocations = [];
  bool get _cameraPending => _cameraBase != null;
  int _cameraDartCount = 0;
  bool _cameraRemoved = false;
  bool _confirmingCamera = false;

  bool _previewCameraVisit(List<DartThrowResult> darts, List<bool?> overrides) {
    if (_leaving ||
        _cameraRemoved ||
        (!_cameraPending && (controller.isBotTurn || controller.isComplete))) {
      return false;
    }
    _cameraBase ??= controller.exportActions();
    final preview = ScorerController(widget.settings)
      ..restoreActions(_cameraBase!);
    final player = preview.activePlayer;
    _cameraAttempts = [];
    for (var i = 0; i < darts.length; i++) {
      final attempt =
          overrides[i] ??
          (widget.settings.checkoutRequirement ==
                  CheckoutRequirement.doubleOut &&
              preview.maxCheckoutAttempts(darts: 1) > 0 &&
              (widget.settings.startRequirement ==
                      StartRequirement.straightIn ||
                  preview.progress.openedLeg));
      _cameraAttempts.add(attempt);
      preview.throwDart(
        darts[i],
        checkoutAttempt: attempt,
        location: i < _cameraLocations.length ? _cameraLocations[i] : null,
      );
      if (preview.isComplete ||
          preview.activePlayer != player ||
          preview.visit.isEmpty) {
        break;
      }
    }
    final ended =
        darts.isNotEmpty &&
        (preview.isComplete ||
            preview.activePlayer != player ||
            preview.visit.isEmpty);
    _cameraDartCount = darts.length;
    controller.replaceActions(preview.exportActions());
    preview.dispose();
    return ended;
  }

  Future<void> _confirmCameraVisit(List<DartThrowResult> _) async {
    if (!_cameraPending || _confirmingCamera) return;
    if (!_cameraRemoved) _audio.confirmRemoval();
    setState(() {
      _cameraRemoved = true;
      _confirmingCamera = true;
    });
    try {
      while (controller.visit.isNotEmpty && !controller.isComplete) {
        final dart = await showDialog<DartThrowResult>(
          context: context,
          builder: (_) => DartCorrectionDialog(
            title:
                'Dart ${controller.visit.length + 1} nicht erfasst · bitte nachtragen',
          ),
        );
        if (!mounted || dart == null) return;
        controller.throwDart(dart);
      }
    } finally {
      if (mounted) setState(() => _confirmingCamera = false);
    }
    if (!mounted) return;
    _cameraBase = null;
    _cameraRemoved = false;
    _cameraAttempts = [];
    _changed();
    _publishCamera();
  }

  void _closeCamera() {
    final previous = _cameraBase;
    if (previous != null) controller.replaceActions(previous);
    _cameraBase = null;
    _cameraRemoved = false;
    _cameraAttempts = [];
    setState(() => _localCameraOpen = false);
    _publishCamera();
    _scheduleBot();
  }

  Future<void> _submitBust() async {
    if (!_inputReady) return;
    final expectedRevision = widget.remote?.revision;
    if (_bustPending || controller.isBotTurn || controller.isComplete) {
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
      if (_isRemote) {
        await widget.remote!.command(
          'bust',
          expectedRevision: expectedRevision,
          values: {'attempts': attempts},
        );
      } else {
        controller.submitBust(checkoutAttempts: attempts);
      }
    } finally {
      _bustPending = false;
    }
  }

  @override
  void initState() {
    super.initState();
    controller = widget.remote?.controller ?? ScorerController(widget.settings);
    if (widget.draft != null) {
      controller.restoreActions(widget.draft!['actions'] as List);
      _hadHeatmap = controller.hits.isNotEmpty;
    }
    _scorerAudio = ScorerAudioController(_audio, controller);
    controller.addListener(_changed);
    _scheduleBot();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_checkAutomaticCamera());
      if (mounted) unawaited(_startDefaultMonitor());
    });
  }

  void _changed() {
    setState(() {});
    if (_isRemote) return;
    _scorerAudio.update(
      controller,
      provisional: _cameraPending,
      cameraDarts: _cameraDartCount,
    );
    _publishCamera();
    if (!_cameraPending) _persistStatistics();
    _scheduleBot();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tryAutomaticCamera();
    });
    if (!_cameraPending && controller.isComplete) {
      widget.onCompleted?.call(controller);
    }
  }

  void _scheduleBot() {
    timer?.cancel();
    if (_isRemote) return;
    if (!_leaving && !_cameraPending && controller.isBotTurn) {
      timer = Timer(widget.settings.botThrowDelay, controller.playBotDart);
    }
  }

  @override
  void dispose() {
    unawaited(_monitor.close());
    _audio.dispose();
    timer?.cancel();
    controller.removeListener(_changed);
    _remoteHost?.detach(controller);
    if (!_isRemote) controller.dispose();
    super.dispose();
  }

  Future<bool> _submit(int points) async {
    if (!_inputReady) return false;
    final expectedRevision = widget.remote?.revision;
    final c = controller;
    if (c.isBotTurn || c.isComplete) return false;
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
      final maximum = c.maxCheckoutAttempts(darts: darts ?? 3, points: points);
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
      if (_isRemote) {
        return widget.remote!.command(
          'score',
          expectedRevision: expectedRevision,
          values: {'points': points, 'darts': darts, 'attempts': attempts},
        );
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

  void _showPlayDetailsSheet(bool target) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .8,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder: (context, refresh) => target
                  ? HeatmapTargetPicker(
                      target: controller.intendedTarget,
                      player: controller.activePlayer,
                      onChanged: _leaving || _cameraPending
                          ? null
                          : (value) {
                              setState(() => controller.intendedTarget = value);
                              refresh(() {});
                            },
                    )
                  : ScorerLegSheet(
                      settings: widget.settings,
                      visits: controller.statisticsVisits,
                      leg: controller.displayedLeg,
                      starter: controller.legStarter,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final statistics = c.statistics;
    final board = Builder(
      builder: (context) {
        final compact = ScorerPlaySizing.of(context)?.compact ?? false;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.settings.startScore} · ${checkoutLabel(widget.settings.checkoutRequirement)} · Best of ${widget.settings.bestOfLegs} Legs'
              '${widget.settings.bestOfSets > 1 ? ' · Best of ${widget.settings.bestOfSets} Sets' : ''}',
            ),
            SizedBox(height: compact ? 4 : 12),
            ScorerScoreboard(
              players: [
                for (var i = 0; i < widget.settings.participants.length; i++)
                  ScorerScoreboardPlayer(
                    name: widget.settings.participants[i].name,
                    score: i == c.activePlayer && !c.isComplete
                        ? c.remaining
                        : c.scores[i],
                    legs: c.legs[i],
                    sets: c.sets[i],
                    average: statistics.players[i].average,
                    active: i == c.activePlayer && !c.isComplete,
                    bot: widget.settings.participants[i].bot != null,
                  ),
              ],
            ),
            SizedBox(height: compact ? 4 : 12),
            if (c.isComplete)
              Text(
                c.isDraw
                    ? 'Unentschieden!'
                    : '${widget.settings.participants[c.winner!].name} gewinnt!',
                style: Theme.of(context).textTheme.headlineSmall,
              )
            else if (!compact) ...[
              Text(
                '${c.activeThrower} ist am Wurf${widget.settings.participants[c.activePlayer].isTeam ? ' · ${widget.settings.participants[c.activePlayer].name}' : ''}${c.isBotTurn ? ' · Bot' : ''}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (c.isBotTurn) const LinearProgressIndicator(),
            ],
            if (c.message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(c.message),
            ],
            if (!compact && !c.isComplete && !c.isBotTurn && !_isRemote)
              HeatmapTargetPicker(
                target: c.intendedTarget,
                player: c.activePlayer,
                onChanged: _leaving || _cameraPending
                    ? null
                    : (value) => setState(() => c.intendedTarget = value),
              ),
            if (!c.isComplete && c.remaining <= 180)
              PersonalizedCheckoutRoutes(
                compact: compact,
                accountId: widget.accountId,
                enabled: c.activePlayer == widget.profilePlayerIndex,
                score: c.remaining,
                dartsLeft: c.dartsLeft,
                requirement: widget.settings.checkoutRequirement,
              ),
          ],
        );
      },
    );
    final pad = Builder(
      builder: (context) {
        final compact = ScorerPlaySizing.of(context)?.compact ?? false;
        return Column(
          children: [
            if (_cameraOpen && !_isRemote)
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _showCameraDetails = !_showCameraDetails),
                icon: Icon(
                  _showCameraDetails
                      ? Icons.visibility_off
                      : Icons.edit_location_alt_outlined,
                ),
                label: Text(
                  _showCameraDetails
                      ? 'Autoscoring-Korrektur ausblenden'
                      : 'Autoscoring aktiv · Darts korrigieren',
                ),
              ),
            if (_cameraOpen && !_isRemote)
              Visibility(
                visible: _showCameraDetails,
                maintainState: true,
                child: ScorerCameraPanel(
                  key: _cameraPanelKey,
                  activity: controller,
                  isInputEnabled: () =>
                      _cameraOpen &&
                      !_leaving &&
                      !_cameraRemoved &&
                      (_cameraPending ||
                          (!controller.isBotTurn && !controller.isComplete)),
                  dartsLeftProvider: () => controller.dartsLeft,
                  dartsLeft: c.dartsLeft,
                  enabled:
                      !_leaving &&
                      !_cameraRemoved &&
                      (_cameraPending || (!c.isBotTurn && !c.isComplete)),
                  onAccept: _confirmCameraVisit,
                  onPreview: _previewCameraVisit,
                  onLocations: (locations) => _cameraLocations = locations,
                  attempts: _cameraAttempts,
                  onClose: _closeCamera,
                ),
              ),
            if (_cameraRemoved && !_confirmingCamera && !_isRemote)
              FilledButton(
                onPressed: () => _confirmCameraVisit(const []),
                child: const Text(
                  'Fehlende Darts nachtragen · Aufnahme abschließen',
                ),
              ),
            if (_cameraOpen && _isRemote) ...[
              const Text(
                'Autoscoring läuft am Hauptgerät. Erkannte Würfe werden hier angezeigt.',
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final dart
                      in (widget.remote!.state?['cameraDarts'] as List? ??
                          const []))
                    Chip(label: Text(dart as String)),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.remote!.state?['cameraPending'] == true)
                    FilledButton(
                      onPressed: _inputReady
                          ? () => widget.remote!.command('cameraConfirm')
                          : null,
                      child: const Text('Aufnahme übernehmen'),
                    ),
                  OutlinedButton(
                    onPressed: _inputReady
                        ? () => widget.remote!.command('cameraClose')
                        : null,
                    child: const Text('Autoscoring beenden'),
                  ),
                ],
              ),
            ],
            Visibility(
              visible: !_cameraOpen,
              maintainState: true,
              child: Column(
                children: [
                  ScoreKeypad(
                    key: _scoreKeypadKey,
                    enabled:
                        _inputReady &&
                        !_cameraOpen &&
                        !_leaving &&
                        !c.isComplete &&
                        !c.isBotTurn,
                    remaining: c.remaining,
                    onSubmit: _submit,
                    onBust: _submitBust,
                    onUndo:
                        _inputReady && !_cameraOpen && !_leaving && c.canUndo
                        ? _undo
                        : null,
                  ),
                  if (!compact)
                    const Text(
                      'Summe der Aufnahme eingeben und mit OK bestätigen.\nTastatur: Ziffern, Enter, Rücktaste, Esc.',
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 12),
              Text(
                _isRemote
                    ? 'Die Partie und ihre Statistiken werden am Hauptgerät geführt.'
                    : 'Beim Verlassen kannst du die Partie zwischenspeichern.',
                textAlign: TextAlign.center,
              ),
              if (widget.accountId != null)
                const Text(
                  'Erfasste Aufnahmen bleiben in deinem Profil gespeichert.',
                  textAlign: TextAlign.center,
                ),
            ],
          ],
        );
      },
    );
    final scorer = PopScope(
      canPop:
          !_deviceMonitor &&
          (_mayLeave || (widget.onExit != null && widget.accountId == null)),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _deviceMonitor) {
          setState(() => _deviceMonitor = false);
          return;
        }
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: widget.onExit == null
              ? null
              : IconButton(
                  tooltip: _isRemote
                      ? 'Fernsteuerung trennen'
                      : 'Zur Geräteverwaltung',
                  onPressed: widget.onExit,
                  icon: const Icon(Icons.arrow_back),
                ),
          title: Text(c.isComplete ? 'Spielauswertung' : 'X01 Scorer'),
          actions: [
            if (!_isRemote)
              IconButton(
                tooltip: 'Caller und Sounds',
                onPressed: _showAudio,
                icon: const Icon(Icons.volume_up_outlined),
              ),
            IconButton(
              tooltip: 'Heatmap dieses Spiels',
              icon: const Icon(Icons.blur_on),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ScorerHeatmapPage(
                    sessions: [
                      ScorerHeatmapSession(
                        id: _sessionId,
                        date: _playedAt,
                        names: [
                          for (final p in widget.settings.participants) p.name,
                        ],
                        hits: controller.hits,
                        complete: controller.isComplete,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Autoscorer · drei Kameras',
              onPressed:
                  !_inputReady ||
                      (_isRemote &&
                          widget.remote!.state?['cameraAvailable'] != true) ||
                      controller.isBotTurn ||
                      controller.isComplete
                  ? null
                  : _openAutoscoring,
              icon: const Icon(Icons.videocam_outlined),
            ),
            PopupMenuButton<String>(
              tooltip: 'Partie-Details',
              icon: const Icon(Icons.more_vert),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'statistics',
                  child: Text('Matchstatistik'),
                ),
                const PopupMenuItem(
                  value: 'history',
                  child: Text('Schreibertafel · Leg-Verlauf'),
                ),
                if (!_isRemote && !c.isComplete && !c.isBotTurn)
                  const PopupMenuItem(
                    value: 'target',
                    child: Text('Heatmap-Wurfziel'),
                  ),
                const PopupMenuItem(
                  value: 'monitor',
                  child: Text('Monitor-Modus'),
                ),
              ],
              onSelected: (value) {
                if (value == 'statistics') _showStatistics();
                if (value == 'monitor') _chooseMonitor();
                if (value == 'history' || value == 'target') {
                  _showPlayDetailsSheet(value == 'target');
                }
              },
            ),
          ],
        ),
        bottomNavigationBar: _saveError == null && _heatmapError == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      Text(_heatmapError ?? _saveError!),
                      TextButton(
                        onPressed: _persistStatistics,
                        child: const Text('Erneut speichern'),
                      ),
                    ],
                  ),
                ),
              ),
        body:
            c.isComplete &&
                !_cameraPending &&
                (!_isRemote || widget.remote!.state?['cameraPending'] != true)
            ? ScorerResultView(
                settings: widget.settings,
                statistics: statistics,
                sets: c.sets,
                winner: c.winner,
                onStatistics: _showStatistics,
                onClose: _leaving ? null : widget.onExit ?? _leave,
                onUndo: _inputReady && !_cameraOpen && !_leaving && c.canUndo
                    ? _undo
                    : null,
              )
            : SafeArea(
                child: ScorerPlayLayout(
                  expandScores: _cameraOpen && !_showCameraDetails,
                  board: board,
                  input: pad,
                  toolbar: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _chooseMonitor,
                      icon: const Icon(Icons.monitor),
                      label: const Text('Monitor-Modus'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                  ),
                  history: ScorerLegSheet(
                    settings: widget.settings,
                    visits: c.statisticsVisits,
                    leg: c.displayedLeg,
                    starter: c.legStarter,
                  ),
                ),
              ),
      ),
    );
    // Keep camera recognition and match state mounted behind the display.
    return Stack(
      children: [
        Offstage(offstage: _deviceMonitor, child: scorer),
        if (_deviceMonitor)
          Positioned.fill(
            child: ScorerMonitorPage(
              controller: controller,
              onClose: () => setState(() => _deviceMonitor = false),
            ),
          ),
      ],
    );
  }
}
