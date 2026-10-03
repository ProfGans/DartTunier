import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../devices/domain/app_device.dart';
import 'remote_control_page.dart';
import 'remote_host_surface.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../domain/remote_pairing_code.dart';

class RemoteDeviceSection extends StatefulWidget {
  const RemoteDeviceSection({super.key, this.peers = const []});
  final List<DevicePresence> peers;
  @override
  State<RemoteDeviceSection> createState() => _RemoteDeviceSectionState();
}

class _RemoteDeviceSectionState extends State<RemoteDeviceSection> {
  bool _opened = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    final host = RemoteHostScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) host.refreshAccountDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final host = RemoteHostScope.of(context);
    return AnimatedBuilder(
      animation: host,
      builder: (context, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'App fernsteuern',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Die gesamte App von einer installierten App im selben WLAN bedienen. Das Hauptgerät bleibt geöffnet und speichert alle Änderungen.',
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dieses Gerät zur Fernsteuerung freigeben'),
                value: host.enabled,
                onChanged:
                    host.starting || host.settingsBusy || !host.settingsReady
                    ? null
                    : (enabled) async {
                        if (enabled) {
                          await host.setEnabled(true);
                        } else {
                          await host.setEnabled(false);
                        }
                      },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Übernahme bestätigen'),
                subtitle: const Text(
                  'Aus: Geräte desselben Accounts verbinden direkt. Ein: Jede Verbindung muss hier bestätigt werden. Andere Geräte benötigen weiterhin einen Kopplungscode.',
                ),
                value: host.requireConfirmation,
                onChanged: host.settingsBusy || !host.settingsReady
                    ? null
                    : host.setRequireConfirmation,
              ),
              if (host.accountId == null)
                const Text(
                  'Für die Verbindung ohne QR-Code auf beiden Geräten mit demselben Account anmelden.',
                ),
              if (host.accountError != null) Text(host.accountError!),
              if (host.error != null) Text(host.error!),
              if (host.enabled) ...[
                Text(
                  host.connected
                      ? 'Fernbedienung verbunden'
                      : 'Warte auf Fernbedienung',
                ),
                SelectableText('IP-Adresse: ${host.addresses.join(' / ')}'),
                const Text(
                  'Kopplungscode auf dem Handy eingeben. Nur an die gewünschte Fernbedienung weitergeben.',
                ),
                SelectableText(host.pairingKey ?? ''),
                if (host.addresses.isNotEmpty && host.pairingKey != null)
                  for (final address in host.addresses)
                    ExpansionTile(
                      initiallyExpanded: host.addresses.length == 1,
                      title: Text('QR-Code für $address'),
                      children: [
                        Semantics(
                          label: 'QR-Code zum Koppeln der Fernbedienung',
                          child: QrImageView(
                            data: RemotePairingCode(
                              address,
                              host.pairingKey!,
                            ).encode(),
                            size: 220,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                TextButton.icon(
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: host.pairingKey ?? ''),
                  ),
                  icon: const Icon(Icons.copy),
                  label: const Text('Kopplungscode kopieren'),
                ),
                const Text(
                  'Freigabe beenden trennt die Fernbedienung und macht diesen Code ungültig.',
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RemoteControlPage(),
                  ),
                ),
                icon: const Icon(Icons.phonelink),
                label: const Text('Anderes Gerät fernsteuern'),
              ),
              if (host.accountId != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Fernsteuerbare Geräte meines Accounts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: host.accountBusy
                      ? null
                      : host.refreshAccountDevices,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Account-Geräte aktualisieren'),
                ),
                if (host.accountBusy) const LinearProgressIndicator(),
                if (!host.accountBusy && host.accountDevices.isEmpty)
                  const Text(
                    'Noch keine Account-Freigabe gefunden. Auf dem anderen Gerät die Fernsteuerung freigeben.',
                  ),
                for (final entry in host.accountDevices)
                  ListTile(
                    title: Text(entry.device.name),
                    subtitle: Text(
                      '${entry.device.platform} · ${entry.addresses.join(' / ')}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Mit demselben Account fernsteuern',
                      icon: const Icon(Icons.phonelink),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              RemoteControlPage(accountDevice: entry),
                        ),
                      ),
                    ),
                  ),
              ],
              for (final peer in widget.peers)
                ListTile(
                  title: Text(peer.device.name),
                  subtitle: Text(peer.address),
                  trailing: IconButton(
                    tooltip: 'Dieses Gerät fernsteuern',
                    icon: const Icon(Icons.phonelink),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            RemoteControlPage(address: peer.address),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
