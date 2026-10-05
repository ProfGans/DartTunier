import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Desktop capture runs independently of focus and window visibility.
/// Mobile background capture requires a separate native service.
bool pauseAutoscoreForLifecycle(
  AppLifecycleState state, {
  TargetPlatform? platform,
}) {
  if (state == AppLifecycleState.detached) return true;
  final target = platform ?? defaultTargetPlatform;
  final desktop =
      !kIsWeb &&
      [
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      ].contains(target);
  return !desktop && state != AppLifecycleState.resumed;
}
