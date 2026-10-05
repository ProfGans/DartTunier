import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../scorer/application/scorer_controller.dart';
import '../../scorer/data/scorer_draft_storage.dart';
import '../../scorer/domain/scorer_settings.dart';

/// The host alone changes the match. Commands target an exact session/revision.
class RemoteScorerHost extends ChangeNotifier {
  ScorerController? _controller;
  Map<String, dynamic>? _completed;
  String? _session;
  int revision = 0;
  bool _busy = false;
  bool cameraAvailable = false, cameraOpen = false, cameraPending = false;
  Future<void> Function(ScorerSettings settings)? startMatch;
  Future<void> Function(String action)? cameraAction;
  final _seen = <String, String?>{};
  List<String> cameraDarts = const [];
  bool owns(ScorerController controller) => identical(controller, _controller);

  Map<String, dynamic> _reply(String id, {String? error}) {
    _seen[id] = error;
    if (_seen.length > 256) _seen.remove(_seen.keys.first);
    return snapshot(commandId: id, error: error);
  }

  void attach(ScorerController controller, String session) {
    if (identical(controller, _controller)) return;
    _controller?.removeListener(touch);
    _controller = controller;
    _completed = null;
    _session = session;
    cameraAvailable = cameraOpen = cameraPending = false;
    cameraDarts = const [];
    controller.addListener(touch);
    touch();
  }

  void detach(ScorerController controller) {
    if (!identical(controller, _controller)) return;
    _completed = controller.isComplete && !cameraPending
        ? {
            'settings': ScorerDraftStorage.encodeSettings(controller.settings),
            'actions': controller.exportActions(),
          }
        : null;
    controller.removeListener(touch);
    _controller = null;
    if (_completed == null) _session = null;
    cameraAction = null;
    cameraAvailable = cameraOpen = cameraPending = false;
    cameraDarts = const [];
    touch();
  }

  void cameraState({
    required bool available,
    required bool open,
    required bool pending,
    List<String> darts = const [],
  }) {
    if (cameraAvailable == available &&
        cameraOpen == open &&
        cameraPending == pending &&
        listEquals(cameraDarts, darts)) {
      return;
    }
    cameraAvailable = available;
    cameraOpen = open;
    cameraPending = pending;
    cameraDarts = List.unmodifiable(darts);
    touch();
  }

  void touch() {
    revision++;
    notifyListeners();
  }

  Map<String, dynamic> snapshot({String? commandId, String? error}) => {
    'type': 'scorerState',
    'version': 1,
    'revision': revision,
    'sessionId': _session,
    'busy': _busy,
    'canStart': startMatch != null && _controller == null && _completed == null,
    'resultFinalized': _completed != null,
    'cameraAvailable': cameraAvailable,
    'cameraOpen': cameraOpen,
    'cameraPending': cameraPending,
    'cameraDarts': cameraDarts,
    if (_controller != null) ...{
      'settings': ScorerDraftStorage.encodeSettings(_controller!.settings),
      'actions': _controller!.exportActions(),
    },
    if (_completed != null) ..._completed!,
    'commandId': commandId,
    'error': error,
  };

  Future<Map<String, dynamic>> execute(Map<String, dynamic> message) async {
    final id = message['commandId'];
    if (id is! String || id.isEmpty || id.length > 100) {
      return snapshot(error: 'Ungültige Eingabe.');
    }
    if (_seen.containsKey(id)) return snapshot(commandId: id, error: _seen[id]);
    if (_busy ||
        message['revision'] != revision ||
        message['sessionId'] != _session) {
      return _reply(
        id,
        error:
            'Der Spielstand hat sich geändert. Bitte die Eingabe erneut prüfen.',
      );
    }
    _busy = true;
    try {
      final action = message['action'];
      if (action == 'start') {
        if (_controller != null || startMatch == null) {
          throw StateError('Bereits laufende Partie');
        }
        final settings = ScorerDraftStorage.decodeSettings(
          Map<String, dynamic>.from(message['settings'] as Map),
        );
        if (settings.participants.length > 16 ||
            settings.participants.any((p) => p.name.length > 120)) {
          throw const FormatException('Teilnehmer');
        }
        await startMatch!(settings);
      } else {
        final c = _controller;
        if (c == null) throw StateError('Keine Partie');
        if (action == 'cameraClose' ||
            action == 'cameraConfirm' ||
            action == 'cameraOpen') {
          if (cameraAction == null ||
              (action == 'cameraOpen' && !cameraAvailable)) {
            throw StateError('Keine Kameras');
          }
          await cameraAction!(action as String);
          touch();
        } else {
          if (cameraOpen || cameraPending || c.isBotTurn) {
            throw StateError('Aufnahme läuft');
          }
          switch (action) {
            case 'score':
              if (c.isComplete || c.visit.isNotEmpty) {
                throw StateError('Aufnahme läuft oder Spiel beendet');
              }
              c.submitScore(
                message['points'] as int,
                checkoutDarts: message['darts'] as int?,
                checkoutAttempts: message['attempts'] as int?,
              );
            case 'bust':
              if (c.isComplete || c.visit.isNotEmpty) {
                throw StateError('Aufnahme läuft oder Spiel beendet');
              }
              c.submitBust(checkoutAttempts: message['attempts'] as int?);
            case 'undo':
              if (!c.canUndo) throw StateError('Kein Wurf');
              c.undo();
            default:
              throw const FormatException('Aktion');
          }
        }
      }
      _busy = false;
      return _reply(id);
    } catch (_) {
      _busy = false;
      return _reply(
        id,
        error:
            'Die Eingabe konnte am Hauptgerät nicht übernommen werden. Spielstand und Aufnahme prüfen.',
      );
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(touch);
    super.dispose();
  }
}
