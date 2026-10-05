import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../scorer/application/scorer_controller.dart';
import '../../scorer/data/scorer_draft_storage.dart';

/// A local presentation model, rebuilt only from the authoritative host history.
class RemoteScorerClient extends ChangeNotifier {
  ScorerController? controller;
  Map<String, dynamic>? state;
  bool connected = false, pending = false;
  bool _needsReconnect = false;
  String? error;
  Future<void> Function(Map<String, dynamic>)? send;
  int _counter = 0;
  String? _pendingId;
  Completer<bool>? _completion;
  Timer? _timeout;
  final String _prefix = DateTime.now().microsecondsSinceEpoch.toString();
  int get revision => state?['revision'] as int? ?? -1;
  String? get sessionId => state?['sessionId'] as String?;
  bool get ready => connected && state != null && !pending;

  void receive(Map<String, dynamic> message) {
    if (message['version'] != 1 || message['revision'] is! int) {
      throw const FormatException('Scorer-Version');
    }
    if ((message['revision'] as int) < revision) return;
    final previous = sessionId;
    final previousActions = state?['actions'];
    if (message['sessionId'] == null) {
      controller?.dispose();
      controller = null;
    } else {
      if (message['sessionId'] != previous || controller == null) {
        controller?.dispose();
        controller = ScorerController(
          ScorerDraftStorage.decodeSettings(
            Map<String, dynamic>.from(message['settings'] as Map),
          ),
        );
      }
      if (previousActions != message['actions']) {
        controller!.replaceActions(message['actions'] as List);
      }
    }
    state = message;
    connected = !_needsReconnect;
    if (message['commandId'] == _pendingId && _pendingId != null) {
      error = message['error'] as String?;
      _finish(error == null);
    }
    notifyListeners();
  }

  Future<bool> command(
    String action, {
    Map<String, dynamic> values = const {},
    int? expectedRevision,
  }) async {
    if (!ready || send == null) return false;
    final id = '$_prefix:${++_counter}';
    final completion = Completer<bool>();
    _completion = completion;
    _pendingId = id;
    pending = true;
    error = null;
    notifyListeners();
    _timeout = Timer(const Duration(seconds: 10), () {
      error =
          'Keine Bestätigung vom Hauptgerät. Vor einer erneuten Eingabe neu verbinden.';
      connected = false;
      _needsReconnect = true;
      _finish(false);
      notifyListeners();
    });
    try {
      await send!({
        'type': 'scorerCommand',
        'version': 1,
        'commandId': id,
        'revision': expectedRevision ?? revision,
        'sessionId': sessionId,
        'action': action,
        ...values,
      });
    } catch (_) {
      disconnect();
    }
    return completion.future;
  }

  void _finish(bool accepted) {
    _timeout?.cancel();
    _timeout = null;
    _pendingId = null;
    pending = false;
    _completion?.complete(accepted);
    _completion = null;
  }

  void disconnect() {
    connected = false;
    _finish(false);
    notifyListeners();
  }

  void beginConnection() {
    _finish(false);
    connected = false;
    state = null;
    error = null;
    _needsReconnect = false;
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _completion?.complete(false);
    controller?.dispose();
    super.dispose();
  }
}
