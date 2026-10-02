import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/scorer_lobby_repository.dart';
import '../domain/scorer_lobby.dart';

class ScorerLobbyController extends ChangeNotifier {
  ScorerLobbyController(this.repository);
  final ScorerLobbyRepository repository;
  ScorerLobby? lobby;
  String? error;
  bool busy = false, _disposed = false, _refreshing = false;
  Timer? _timer;

  Future<void> create() async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final result = await repository.create();
      if (_disposed) {
        await repository.close(result.id);
        return;
      }
      lobby = result;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
    } catch (_) {
      error =
          'Lobby konnte nicht geöffnet werden. Online-Anmeldung, Verbindung und Server-Einrichtung prüfen.';
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> refresh() async {
    final current = lobby;
    if (_disposed || _refreshing || busy || current == null || !current.open) {
      return;
    }
    _refreshing = true;
    try {
      final updated = await repository.snapshot(current.id);
      if (!_disposed &&
          !busy &&
          lobby?.open == true &&
          lobby?.id == current.id) {
        lobby = updated;
        error = null;
      }
    } catch (_) {
      if (!busy) {
        error =
            'Teilnehmer konnten nicht aktualisiert werden. Bitte Verbindung prüfen.';
      }
    } finally {
      _refreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Atomically freeze joins and return the final, server-confirmed roster.
  Future<void> close() async {
    final current = lobby;
    if (current == null || !current.open) return;
    busy = true;
    _timer?.cancel();
    try {
      lobby = await repository.close(current.id);
      error = null;
    } catch (_) {
      if (!_disposed) {
        _timer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
      }
      rethrow;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> remove(String userId) async {
    if (busy || lobby == null) return;
    try {
      await repository.remove(lobby!.id, userId);
      await refresh();
    } catch (_) {
      error = 'Teilnehmer konnte nicht entfernt werden.';
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    final current = lobby;
    if (current != null && current.open) {
      unawaited(
        repository
            .close(current.id)
            .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
    }
    super.dispose();
  }
}
