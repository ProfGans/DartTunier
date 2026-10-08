import 'dart:async';
import 'dart:isolate';

/// A reusable isolate with at most one in-flight job and no hidden backlog.
/// The function must be a top-level/static function with sendable inputs.
class BackgroundWorker<I, O> {
  BackgroundWorker(this.function);
  final FutureOr<O> Function(I) function;
  Isolate? _isolate;
  ReceivePort? _events;
  SendPort? _commands;
  Future<void>? _starting;
  Completer<void>? _ready;
  Completer<O>? _pending;
  bool _closed = false;

  Future<void> _start() async {
    _events = ReceivePort();
    _ready = Completer<void>();
    // Cancellation can happen while Isolate.spawn is still being awaited.
    unawaited(_ready!.future.catchError((Object _) {}));
    _events!.listen((message) {
      if (message is SendPort) {
        _commands = message;
        if (!_ready!.isCompleted) _ready!.complete();
      } else if (message is List && message.first == 'result') {
        final pending = _pending;
        _pending = null;
        pending?.complete(message[1] as O);
      } else {
        final error = StateError('Background worker stopped: $message');
        if (!_ready!.isCompleted) _ready!.completeError(error);
        _pending?.completeError(error);
        _pending = null;
        close();
      }
    });
    try {
      _isolate = await Isolate.spawn(
        _serve<I, O>,
        (_events!.sendPort, function),
        onError: _events!.sendPort,
        onExit: _events!.sendPort,
      );
      if (_closed) _isolate!.kill(priority: Isolate.immediate);
      await _ready!.future;
    } catch (_) {
      close();
      rethrow;
    }
  }

  Future<O> run(I input) async {
    if (_closed) throw StateError('Background worker is closed');
    await (_starting ??= _start());
    if (_closed) throw StateError('Background worker is closed');
    if (_pending != null) throw StateError('Background worker is busy');
    final pending = _pending = Completer<O>();
    try {
      _commands!.send(input);
    } catch (_) {
      _pending = null;
      rethrow;
    }
    return pending.future;
  }

  void close() {
    _closed = true;
    _isolate?.kill(priority: Isolate.immediate);
    _events?.close();
    if (_ready != null && !_ready!.isCompleted) {
      _ready!.completeError(StateError('Background worker closed'));
    }
    _pending?.completeError(StateError('Background worker closed'));
    _pending = null;
  }
}

void _serve<I, O>((SendPort, FutureOr<O> Function(I)) initial) {
  final commands = ReceivePort();
  initial.$1.send(commands.sendPort);
  commands.listen((input) async {
    try {
      initial.$1.send(['result', await initial.$2(input as I)]);
    } catch (error, stack) {
      initial.$1.send(['error', error.toString(), stack.toString()]);
    }
  });
}
