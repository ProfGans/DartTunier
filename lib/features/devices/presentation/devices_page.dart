import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/devices_controller.dart';
import '../domain/app_device.dart';
import 'devices_scope.dart';
import 'device_community_section.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});
  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  Future<void> _showPairing(DevicesController controller) async {
    final key = controller.settings?.pairingKey;
    if (key == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dieses Gerät koppeln'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Diesen Code auf dem Computer der Turnierleitung unter „Boards auf Geräte übertragen“ eingeben. Nur mit diesem Code kann die Anzeige gesteuert werden.',
              ),
              const SizedBox(height: 16),
              SelectableText(key),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: key));
            },
            child: const Text('Code kopieren'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  DevicesController? _controller;
  bool _opened = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= DevicesScope.of(context);
    if (!_opened) {
      _opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller!.openPage();
      });
    }
  }

  @override
  void dispose() {
    _controller?.closePage();
    super.dispose();
  }

  Future<void> _rename(DevicesController controller) async {
    var name = controller.settings!.self.name;
    final form = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gerätename'),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: name,
            maxLength: 80,
            autofocus: true,
            onChanged: (value) => name = value,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Bitte einen Namen eingeben.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, name.trim());
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (result != null && mounted) await controller.rename(result);
  }

  @override
  Widget build(BuildContext context) {
    final controller = DevicesScope.of(context);
    final settings = controller.settings;
    final peers = {
      for (final peer in controller.discovery.peers) peer.device.id: peer,
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geräte'),
        actions: [
          IconButton(
            tooltip: 'Geräte aktualisieren',
            icon: const Icon(Icons.refresh),
            onPressed: controller.busy ? null : controller.refresh,
          ),
        ],
      ),
      body: settings == null
          ? Center(
              child: controller.error == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(controller.error!),
                        TextButton(
                          onPressed: controller.refresh,
                          child: const Text('Erneut versuchen'),
                        ),
                      ],
                    ),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Dieser Computer',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.computer),
                        title: Text(settings.self.name),
                        subtitle: Text(settings.self.platform),
                        trailing: IconButton(
                          tooltip: 'Gerätename ändern',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: controller.busy
                              ? null
                              : () => _rename(controller),
                        ),
                      ),
                      SwitchListTile(
                        title: const Text('Als Gerät bereitstellen'),
                        subtitle: const Text(
                          'Andere App-Computer im selben Netzwerk können dieses Gerät finden, solange die App geöffnet ist.',
                        ),
                        value: settings.enabled,
                        onChanged: controller.busy
                            ? null
                            : controller.setEnabled,
                      ),
                    ],
                  ),
                ),
                const Text(
                  'In der Turnieransicht über „Boards auf Geräte übertragen“ verbinden. Laufende und nächste Spiele werden anschließend automatisch angezeigt.',
                ),
                if (settings.enabled) ...[
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showPairing(controller),
                        icon: const Icon(Icons.key),
                      label: const Text('Code für ältere App-Versionen'),
                      ),
                      TextButton(
                        onPressed: controller.busy
                            ? null
                            : controller.resetPairing,
                        child: const Text('Kopplungen zurücksetzen'),
                      ),
                      if (controller.receiver.display != null)
                        FilledButton(
                          onPressed: () => controller.setShowDisplay(true),
                          child: const Text('Zur Spielanzeige'),
                        ),
                    ],
                  ),
                  const Text('Neue Kopplungen hier per Anfrage bestätigen. Zurücksetzen trennt bisherige Kopplungen.'),
                  if (controller.receiver.error != null)
                    _notice(controller.receiver.error!),
                ],
                if (controller.busy) const LinearProgressIndicator(),
                if (controller.error != null) _notice(controller.error!),
                if (controller.discovery.error != null)
                  _notice(controller.discovery.error!),
                const SizedBox(height: 24),
                Text(
                  'Geräte meines Accounts',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text(
                  'Auf jedem Computer mit demselben Account anmelden und das jeweilige Gerät hinzufügen. Die Registrierung sagt noch nicht aus, ob das Gerät erreichbar ist.',
                ),
                if (controller.accountRepository.userId == null)
                  const Text(
                    'Zum Registrieren bitte im Hauptmenü mit einem Online-Account anmelden.',
                  )
                else ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: controller.busy || !settings.enabled
                          ? null
                          : controller.registerSelf,
                      icon: const Icon(Icons.add_to_queue),
                      label: Text(
                        controller.accountDevices.any(
                              (d) => d.id == settings.self.id,
                            )
                            ? 'Registrierung aktualisieren'
                            : 'Diesen Computer dem Account hinzufügen',
                      ),
                    ),
                  ),
                  if (!settings.enabled)
                    const Text(
                      'Zum Hinzufügen zuerst den Gerätemodus aktivieren.',
                    ),
                  if (controller.accountError != null)
                    _notice(controller.accountError!),
                  for (final device in controller.accountDevices)
                    _deviceTile(
                      device,
                      status: device.id == settings.self.id
                          ? 'Dieser Computer'
                          : peers.containsKey(device.id)
                          ? 'Im Netzwerk gefunden'
                          : 'Registriert · Erreichbarkeit unbekannt',
                      action: IconButton(
                        tooltip: 'Aus Account entfernen',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: controller.busy
                            ? null
                            : () => controller.removeAccountDevice(device.id),
                      ),
                    ),
                ],
                if (controller.accountRepository.userId != null)
                  DeviceCommunitySection(
                    key: ValueKey(controller.accountRepository.userId),
                    device: settings.self,
                  ),
                const SizedBox(height: 24),
                Text(
                  'Hinzugefügte Netzwerkgeräte',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (settings.savedDevices.isEmpty)
                  const Text('Noch keine Netzwerkgeräte hinzugefügt.'),
                for (final device in settings.savedDevices)
                  _deviceTile(
                    peers[device.id]?.device ?? device,
                    status: peers.containsKey(device.id)
                        ? 'Im Netzwerk gefunden · ${peers[device.id]!.address}'
                        : 'Aktuell nicht im Netzwerk gefunden',
                    action: IconButton(
                      tooltip: 'Netzwerkgerät entfernen',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: controller.busy
                          ? null
                          : () => controller.forget(device.id),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Im selben Netzwerk',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text(
                  'Auf dem anderen Computer den Gerätemodus aktivieren. Die Suche läuft hier automatisch und benötigt kein Internet.',
                ),
                if (peers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Noch kein Gerät gefunden. Beide Computer müssen im selben Netzwerk sein; die Firewall muss die App zulassen.',
                    ),
                  ),
                for (final peer in peers.values.where(
                  (p) => !settings.savedDevices.any((d) => d.id == p.device.id),
                ))
                  _deviceTile(
                    peer.device,
                    status: peer.address,
                    action: IconButton(
                      tooltip: 'Netzwerkgerät hinzufügen',
                      icon: const Icon(Icons.add),
                      onPressed: controller.busy
                          ? null
                          : () => controller.remember(peer.device),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _notice(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(text),
  );
  Widget _deviceTile(
    AppDevice device, {
    required String status,
    required Widget action,
  }) => Card(
    child: ListTile(
      leading: const Icon(Icons.desktop_windows_outlined),
      title: Text(device.name),
      subtitle: Text('${device.platform} · $status'),
      trailing: action,
    ),
  );
}
