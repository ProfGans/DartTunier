import 'package:flutter/material.dart';
import '../../scorer/application/scorer_controller.dart';
import '../../scorer/presentation/scorer_match_page.dart';
import '../../statistics/domain/saved_scorer_match.dart';
import '../../tournaments/data/tournament_storage.dart';
import '../application/device_scorer_settings.dart';
import '../data/board_display_server.dart';
import '../domain/board_display.dart';

class DeviceScorerSession extends StatefulWidget {
  const DeviceScorerSession({
    super.key,
    required this.display,
    required this.receiver,
    required this.onExit,
    this.storage,
  });
  final BoardDisplay display;
  final BoardDisplayServer receiver;
  final VoidCallback onExit;
  final TournamentStorage? storage;
  @override
  State<DeviceScorerSession> createState() => _DeviceScorerSessionState();
}

class _DeviceScorerSessionState extends State<DeviceScorerSession> {
  late final _storage = widget.storage ?? TournamentStorage();
  late final _settings = deviceScorerSettings(widget.display);
  late final _restoring = _restore();
  Map<String, dynamic>? _result;
  String? _error;
  String get _cacheKey => 'device-result-v1:${widget.display.matchId}';
  Future<void> _restore() async {
    final saved = await _storage.readCache(_cacheKey);
    if (saved != null && saved.isNotEmpty) {
      _result = Map<String, dynamic>.from(saved.single as Map);
      widget.receiver.completeMatch(_result!);
    }
  }

  Future<void> _send() async {
    try {
      await _storage.writeCache(_cacheKey, [_result!]);
      widget.receiver.completeMatch(_result!);
      if (mounted) setState(() => _error = null);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Ergebnis konnte nicht gesichert werden.');
      }
    }
  }

  void _complete(ScorerController controller) {
    if (_result != null) return;
    final statistics = SavedScorerMatch(
      id: widget.display.matchId!,
      accountId: '',
      playedAt: DateTime.now(),
      playerIndex: 0,
      names: [widget.display.home, widget.display.away],
      startScores: [_settings.startScore, _settings.startScore],
      standard501Rules:
          widget.display.gameFormat!.doubleIn == false &&
          widget.display.gameFormat!.checkoutType == 'double_out',
      doubleOut: widget.display.gameFormat!.checkoutType == 'double_out',
      visits: controller.statisticsVisits,
      winner: controller.winner,
      isDraw: controller.isDraw,
    );
    setState(
      () => _result = {
        'version': 1,
        'matchId': widget.display.matchId,
        'legs': [for (final p in controller.statistics.players) p.legsWon],
        'sets': controller.sets.toList(),
        'statistics': statistics.toJson(),
      },
    );
    _send();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _restoring,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError || _result != null) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Board ${widget.display.board}'),
            leading: IconButton(
              tooltip: 'Zur Geräteverwaltung',
              onPressed: widget.onExit,
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error ??
                        (snapshot.hasError
                            ? 'Gespeichertes Ergebnis konnte nicht geladen werden.'
                            : 'Spiel beendet. Ergebnis und Statistiken werden an die Turnierleitung übertragen.'),
                  ),
                  if (_error != null)
                    TextButton(
                      onPressed: _send,
                      child: const Text('Erneut versuchen'),
                    ),
                ],
              ),
            ),
          ),
        );
      }
      return ScorerMatchPage(
        settings: _settings,
        onCompleted: _complete,
        onExit: widget.onExit,
      );
    },
  );
}
