import 'dart:async';
import '../data/tournament_storage.dart';

/// Retries persisted pending uploads while the application is running.
/// Empty outboxes cause no network requests.
class TournamentSyncService {
  TournamentSyncService({
    TournamentStorage? storage,
    this.interval = const Duration(minutes: 2),
  }) : _storage = storage ?? TournamentStorage();
  final TournamentStorage _storage;
  final Duration interval;
  Timer? _timer;
  bool _running = false;
  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(interval, (_) => unawaited(synchronize()));
    unawaited(synchronize());
  }

  Future<void> synchronize() async {
    if (_running) return;
    _running = true;
    try {
      await _storage.synchronize();
    } catch (_) {
      // Local outbox remains intact, including during backup restoration.
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
