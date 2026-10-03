import 'package:flutter/material.dart';
import '../data/app_push_repository.dart';
import '../data/linux_notification_service.dart';

class LinuxPushDeviceMenu extends StatefulWidget {
  const LinuxPushDeviceMenu({super.key, this.service});
  final LinuxNotificationService? service;
  @override
  State<LinuxPushDeviceMenu> createState() => _LinuxPushDeviceMenuState();
}

class _LinuxPushDeviceMenuState extends State<LinuxPushDeviceMenu>
    with WidgetsBindingObserver {
  late final service =
      widget.service ?? LinuxNotificationService(AppPushRepository());
  final name = TextEditingController(text: 'Mein Linux-Gerät');
  bool busy = false, enabled = false;
  String status = 'Linux-Benachrichtigungen werden geprüft …';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final config = await service.configuration();
      final running =
          config != null &&
          config['owner'] == service.repository.userId &&
          await service.active();
      if (!mounted) return;
      if (config != null) name.text = config['name'] as String;
      setState(() {
        enabled = running;
        status = running
            ? 'Empfang aktiv – auch bei geschlossenem App-Fenster, solange du am Linux-Desktop angemeldet bist.'
            : 'Empfang deaktiviert. Online-Anmeldung, Python 3, notify-send und ein systemd-Benutzerdienst werden benötigt.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => status =
              'Linux-Benachrichtigungsdienst nicht verfügbar. Einrichtung und Abhängigkeiten prüfen.',
        );
      }
    }
  }

  Future<void> _configure(bool value) async {
    setState(() => busy = true);
    try {
      if (value) {
        final label = name.text.trim();
        if (label.isEmpty) throw StateError('Gerätename fehlt.');
        await service.enable(label);
      } else {
        await service.disable();
      }
      await _refresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => status =
              'Einrichtung fehlgeschlagen. Online-Anmeldung, Linux-Pakete und die Servermigration für Linux-Benachrichtigungen prüfen.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Linux-Benachrichtigungen',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(status),
          const Text(
            'Nachrichten und aktivierte Turniererinnerungen werden etwa alle 30 Sekunden abgerufen. Aktivieren richtet einen Hintergrunddienst mit automatischem Start bei der Anmeldung ein.',
          ),
          TextField(
            controller: name,
            enabled: !busy,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Gerätename'),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: busy ? null : () => _configure(true),
                child: Text(
                  enabled
                      ? 'Einrichtung aktualisieren'
                      : 'Hintergrundempfang aktivieren',
                ),
              ),
              TextButton(
                onPressed: busy ? null : () => _configure(false),
                child: const Text('Deaktivieren'),
              ),
            ],
          ),
          if (busy) const LinearProgressIndicator(),
        ],
      ),
    ),
  );
}
