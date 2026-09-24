import 'package:flutter/material.dart';
import '../data/community_device_repository.dart';
import 'device_error_message.dart';
import 'community_network_devices.dart';

class CommunityDevicesSection extends StatefulWidget {
  const CommunityDevicesSection({super.key, required this.communityId});
  final String communityId;
  @override
  State<CommunityDevicesSection> createState() =>
      _CommunityDevicesSectionState();
}

class _CommunityDevicesSectionState extends State<CommunityDevicesSection> {
  final repository = CommunityDeviceRepository();
  late Future<List<Map<String, dynamic>>> devices = repository.devices(
    widget.communityId,
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text('Geräte', style: Theme.of(context).textTheme.titleLarge),
          IconButton(
            tooltip: 'Gruppengeräte aktualisieren',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {
              devices = repository.devices(widget.communityId);
            }),
          ),
        ],
      ),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: devices,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(deviceErrorMessage(snapshot.error));
          }
          if (!snapshot.hasData) return const LinearProgressIndicator();
          if (snapshot.data!.isEmpty) {
            return const Text(
              'Noch keine Geräte in dieser Gruppe. Beitritt unter Geräte mit dem Einladungscode dieser Gruppe.',
            );
          }
          return Column(
            children: [
              for (final device in snapshot.data!)
                ListTile(
                  leading: const Icon(Icons.computer),
                  title: Text(device['name'] as String),
                  subtitle: Text('Gerät · ${device['platform']}'),
                ),
            ],
          );
        },
      ),
      const CommunityNetworkDevices(),
    ],
  );
}
