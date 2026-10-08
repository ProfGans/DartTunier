import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/board_display_server.dart';
import '../domain/board_display.dart';

/// Holds only the presentation. Result delivery and incoming assignments continue.
class BoardResultPresentation extends ChangeNotifier {
  BoardResultPresentation(
    this.receiver, {
    this.duration = const Duration(seconds: 20),
  }) {
    receiver.addListener(_update);
    _update();
  }
  final BoardDisplayServer receiver;
  final Duration duration;
  BoardDisplay? _completedDisplay;
  Map<String, dynamic>? result;
  String? _lastCompletion;
  Timer? _timer;
  bool _holding = false;
  BoardDisplay? get display => _completedDisplay ?? receiver.display;

  void skip() {
    _timer?.cancel();
    _holding = false;
    _completedDisplay = null;
    result = null;
    notifyListeners();
  }

  void _update() {
    final incoming = receiver.display;
    final completed = receiver.completedResult;
    if (completed != null &&
        incoming?.matchId == completed['matchId'] &&
        incoming != null &&
        _lastCompletion != '${incoming.tournamentId}:${incoming.matchId}') {
      _lastCompletion = '${incoming.tournamentId}:${incoming.matchId}';
      _completedDisplay = incoming;
      result = Map<String, dynamic>.from(completed);
      _holding = true;
      _timer?.cancel();
      _timer = Timer(duration, () {
        _holding = false;
        _update();
      });
    }
    if (!_holding &&
        _completedDisplay != null &&
        (incoming?.matchId != _completedDisplay!.matchId ||
            incoming?.state != 'running')) {
      _completedDisplay = null;
      result = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    receiver.removeListener(_update);
    super.dispose();
  }
}
