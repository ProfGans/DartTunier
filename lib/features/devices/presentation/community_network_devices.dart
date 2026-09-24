import 'package:flutter/material.dart';
import '../application/devices_controller.dart';
import 'devices_scope.dart';

/// Keeps discovery active for as long as the community's device section exists.
class CommunityNetworkDevices extends StatefulWidget {
  const CommunityNetworkDevices({super.key});
  @override
  State<CommunityNetworkDevices> createState() =>
      _CommunityNetworkDevicesState();
}

class _CommunityNetworkDevicesState extends State<CommunityNetworkDevices> {
  DevicesController? _controller;
  bool _opened = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = DevicesScope.maybeOf(context);
    if (identical(next, _controller)) return;
    if (_opened) _controller?.closePage();
    _opened = false;
    _controller = next;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_controller, next) && next != null) {
        _opened = true;
        next.openPage(loadAccount: false);
      }
    });
  }

  @override
  void dispose() {
    if (_opened) _controller?.closePage();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = DevicesScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    final peers = controller.discovery.peers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Im selben Netzwerk',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Netzwerksuche erneuern',
              onPressed: controller.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const Text(
          'Die Suche läuft automatisch, solange diese Gruppe geöffnet ist. Auf dem Handy oder anderen Computer die App öffnen und „Als Gerät bereitstellen“ aktivieren.',
        ),
        if (controller.discovery.error != null)
          Text(controller.discovery.error!),
        if (peers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Suche läuft · Noch kein Gerät im selben Netzwerk gefunden.',
            ),
          ),
        for (final peer in peers)
          ListTile(
            leading: const Icon(Icons.wifi),
            title: Text(peer.device.name),
            subtitle: Text(
              '${peer.device.platform} · ${peer.address} · Im Netzwerk gefunden',
            ),
          ),
        if (peers.isNotEmpty)
          const Text(
            'Für die Gruppenmitgliedschaft auf dem gefundenen Gerät mit einem Account anmelden und über die Einladung „Als Gerät beitreten“ wählen. Spiele werden in der Turnieransicht über „Boards auf Geräte übertragen“ gekoppelt.',
          ),
      ],
    );
  }
}
