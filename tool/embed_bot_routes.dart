import 'dart:io';

/// Run from the repository root after updating the source route table.
void main() {
  final source = File('assets/scorer/bot_routes_v2.json').readAsStringSync();
  if (source.contains("'''")) throw const FormatException('Unsafe delimiter');
  File(
    'lib/features/scorer/data/repositories/embedded_bot_routes.dart',
  ).writeAsStringSync(
    '// Generated from assets/scorer/bot_routes_v2.json by tool/embed_bot_routes.dart.\n'
    '// Do not edit manually. The parity test guards against stale route data.\n'
    "const embeddedBotRoutesJson = r'''$source''';\n",
  );
}
