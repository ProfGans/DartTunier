import 'package:flutter/material.dart';
import '../../../../shared/widgets/adaptive_content.dart';

enum CommunityArea {
  tournaments(
    'Turniere',
    'Turniere erstellen, fortsetzen und synchronisieren.',
    Icons.emoji_events_outlined,
  ),
  members(
    'Mitglieder',
    'Mitglieder verwalten und manuelle Spieler zuordnen.',
    Icons.groups_outlined,
  ),
  ranking(
    'Rangliste',
    'Elo-Wertungen und Ergebnisse ansehen.',
    Icons.leaderboard_outlined,
  ),
  devices(
    'Geräte',
    'Gruppengeräte anzeigen und im Netzwerk suchen.',
    Icons.devices_outlined,
  ),
  invitations(
    'Einladen',
    'Einladungslink, Code und QR-Code teilen.',
    Icons.qr_code,
  );

  const CommunityArea(this.title, this.description, this.icon);
  final String title;
  final String description;
  final IconData icon;
}

class CommunityMenu extends StatelessWidget {
  const CommunityMenu({
    super.key,
    required this.description,
    required this.onSelected,
  });
  final String description;
  final ValueChanged<CommunityArea> onSelected;

  @override
  Widget build(BuildContext context) => AdaptiveContentList(
    children: [
      Icon(
        Icons.hub_outlined,
        size: 64,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(height: 16),
      Text(
        'Community-Menü',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Text(
        description.isEmpty
            ? 'Wähle einen Bereich deiner Community.'
            : description,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      for (final area in CommunityArea.values)
        Card(
          child: ListTile(
            leading: Icon(area.icon),
            title: Text(area.title),
            subtitle: Text(area.description),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onSelected(area),
          ),
        ),
    ],
  );
}
