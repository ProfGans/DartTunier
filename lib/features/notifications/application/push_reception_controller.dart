import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/app_push_repository.dart';

class PushReceptionController extends ChangeNotifier {
  final repository = AppPushRepository();
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool enabled = false, busy = false, ready = false, disposed = false;
  String name = 'Mein Android-Gerät';
  String status = 'Push ist deaktiviert.';
  void Function(RemoteMessage)? onMessage;
  StreamSubscription<AuthState>? auth;
  StreamSubscription<String>? tokens;
  StreamSubscription<RemoteMessage>? foreground, opened;
  Future<void> queue = Future.value();
  String? lastUser;

  void changed() {
    if (!disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (!supported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (disposed) return;
      enabled = prefs.getBool('app_push.v1.enabled') ?? false;
      name = prefs.getString('app_push.v1.name') ?? name;
      lastUser = repository.userId;
      auth = repository.authChanges?.listen((_) => refresh());
      await refresh();
    } catch (_) {
      status = 'Push-Einstellung konnte nicht geladen werden.';
      changed();
    }
  }

  Future<void> prepare() async {
    if (ready) return;
    await Firebase.initializeApp();
    if (disposed) throw StateError('Controller disposed');
    if (Firebase.app().options.projectId != 'darttunier-6f866') {
      throw StateError('Wrong Firebase project');
    }
    ready = true;
    tokens = FirebaseMessaging.instance.onTokenRefresh.listen((_) => refresh());
    foreground = FirebaseMessaging.onMessage.listen(
      (message) => onMessage?.call(message),
    );
    opened = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => onMessage?.call(message),
    );
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null && !disposed) onMessage?.call(initial);
  }

  Future<void> refresh({bool askPermission = false}) {
    queue = queue.then((_) async {
      if (disposed) return;
      busy = true;
      changed();
      try {
        final user = repository.userId;
        if (ready && user != lastUser) {
          await FirebaseMessaging.instance.setAutoInitEnabled(false);
          await FirebaseMessaging.instance.deleteToken();
        }
        lastUser = user;
        if (!enabled) {
          status = 'Push ist deaktiviert.';
          return;
        }
        if (user == null) {
          status = 'Zum Push-Empfang bitte online anmelden.';
          return;
        }
        await prepare();
        final permission = askPermission
            ? await FirebaseMessaging.instance.requestPermission()
            : await FirebaseMessaging.instance.getNotificationSettings();
        if (permission.authorizationStatus != AuthorizationStatus.authorized &&
            permission.authorizationStatus != AuthorizationStatus.provisional) {
          await FirebaseMessaging.instance.setAutoInitEnabled(false);
          await FirebaseMessaging.instance.deleteToken();
          status =
              'Benachrichtigungen sind nicht erlaubt. Bitte in den Android-Einstellungen erlauben und erneut aktivieren.';
          return;
        }
        await FirebaseMessaging.instance.setAutoInitEnabled(true);
        final token = await FirebaseMessaging.instance.getToken();
        if (token == null || repository.userId != user || disposed) return;
        await repository.client!.rpc(
          'register_app_push_device',
          params: {'p_token': token, 'p_name': name, 'p_platform': 'android'},
        );
        status = 'Dieses Gerät ist für Push registriert.';
      } catch (_) {
        status =
            'Push nicht verfügbar. Firebase-Konfiguration, Internet und Servereinrichtung prüfen.';
      } finally {
        busy = false;
        changed();
      }
    });
    return queue;
  }

  Future<void> configure(bool value, String deviceName) async {
    await queue;
    enabled = value;
    name = deviceName.trim().isEmpty ? 'Mein Android-Gerät' : deviceName.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_push.v1.enabled', enabled);
      await prefs.setString('app_push.v1.name', name);
      if (!value && ready) {
        await FirebaseMessaging.instance.setAutoInitEnabled(false);
        final token = await FirebaseMessaging.instance.getToken();
        // Token deletion works even when the account has already signed out.
        await FirebaseMessaging.instance.deleteToken();
        if (token != null && repository.userId != null) {
          await repository.client!.rpc(
            'unregister_app_push_device',
            params: {'p_token': token},
          );
        }
      }
      await refresh(askPermission: value);
    } catch (_) {
      status =
          'Push-Einstellung konnte nicht gespeichert werden. Bitte erneut versuchen.';
      changed();
    }
  }

  @override
  void dispose() {
    disposed = true;
    auth?.cancel();
    tokens?.cancel();
    foreground?.cancel();
    opened?.cancel();
    onMessage = null;
    super.dispose();
  }
}
