import 'dart:async';
import 'dart:io';

/// Bounded local tools. Arguments never pass through a shell.
Future<ProcessResult> linuxCommand(
  String executable,
  List<String> args, {
  String? input,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final process = await Process.start(executable, args);
  final output = process.stdout.fold<List<int>>([], (a, b) {
    if (a.length + b.length > 8 * 1024 * 1024) {
      process.kill();
      throw StateError('Ausgabe von $executable zu groß.');
    }
    return a..addAll(b);
  });
  final errors = process.stderr.drain<void>();
  output.ignore();
  errors.ignore();
  final work = () async {
    if (input != null) process.stdin.write(input);
    await process.stdin.close();
    final code = await process.exitCode;
    final bytes = await output;
    await errors;
    if (code != 0) throw StateError('$executable fehlgeschlagen (Code $code).');
    return ProcessResult(process.pid, code, bytes, '');
  }();
  try {
    return await work.timeout(timeout);
  } finally {
    process.kill();
  }
}
