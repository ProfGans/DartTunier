import 'package:flutter/material.dart';
import '../../communities/domain/community_invitation.dart';
import '../data/community_device_repository.dart';
import '../domain/app_device.dart';
import 'device_error_message.dart';

/// Mount with an account-specific key so pending requests cannot cross accounts.
class DeviceCommunitySection extends StatefulWidget {
  const DeviceCommunitySection({
    super.key,
    required this.device,
    this.repository,
  });
  final AppDevice device;
  final CommunityDeviceRepository? repository;
  @override
  State<DeviceCommunitySection> createState() => _DeviceCommunitySectionState();
}

class _DeviceCommunitySectionState extends State<DeviceCommunitySection> {
  late final repository = widget.repository ?? CommunityDeviceRepository();
  late Future<List<Map<String, dynamic>>> groups = repository.groups(
    widget.device.id,
  );
  bool busy = false;
  String? error;

  Future<void> _change(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (mounted) {
        setState(() {
          groups = repository.groups(widget.device.id);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error =
              'Änderung fehlgeschlagen. Einladung, Verbindung und Servereinrichtung prüfen.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> _join() async {
    var input = '';
    final form = GlobalKey<FormState>();
    final invitation = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Als Gerät einer Gruppe beitreten'),
        content: Form(
          key: form,
          child: TextFormField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Einladungscode oder Link',
            ),
            onChanged: (value) => input = value,
            validator: (value) =>
                CommunityInvitation.parseInput(value ?? '') == null
                ? 'Gültigen Einladungscode oder Link eingeben.'
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
              if (form.currentState!.validate()) Navigator.pop(context, input);
            },
            child: const Text('Als Gerät beitreten'),
          ),
        ],
      ),
    );
    if (invitation != null && mounted) {
      await _change(() => repository.join(widget.device, invitation));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 24),
      Text(
        'Gruppen dieses Geräts',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const Text(
        'Der Beitritt registriert diesen Computer bei deinem Account und in der Gruppe als Gerät. Dafür ist eine Internetverbindung erforderlich.',
      ),
      OutlinedButton.icon(
        onPressed: busy ? null : _join,
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('Als Gerät einer Gruppe beitreten'),
      ),
      if (busy) const LinearProgressIndicator(),
      if (error != null) Text(error!),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: groups,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return TextButton(
              onPressed: () => setState(() {
                groups = repository.groups(widget.device.id);
              }),
              child: Text(
                '${deviceErrorMessage(snapshot.error)} · Erneut versuchen',
              ),
            );
          }
          if (!snapshot.hasData) return const LinearProgressIndicator();
          if (snapshot.data!.isEmpty) {
            return const Text('Noch keiner Gruppe als Gerät beigetreten.');
          }
          return Column(
            children: [
              for (final group in snapshot.data!)
                ListTile(
                  leading: const Icon(Icons.computer),
                  title: Text(group['community_name'] as String),
                  subtitle: const Text('Mitglied als Gerät'),
                  trailing: IconButton(
                    tooltip: 'Gruppe als Gerät verlassen',
                    icon: const Icon(Icons.logout),
                    onPressed: busy
                        ? null
                        : () => _change(
                            () => repository.leave(
                              group['community_id'] as String,
                              widget.device.id,
                            ),
                          ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}
