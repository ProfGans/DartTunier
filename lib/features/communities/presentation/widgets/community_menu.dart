import 'package:flutter/material.dart';
import '../../../../shared/widgets/adaptive_content.dart';
import 'community_avatar.dart';

enum CommunityArea {
  tournaments(
    'Turniere',
    'Turniere erstellen, fortsetzen und synchronisieren.',
    Icons.emoji_events_outlined,
  ),
  roles(
    'Rollen & Rechte',
    'Rollen erstellen, Berechtigungen festlegen und Mitgliedern zuweisen.',
    Icons.admin_panel_settings_outlined,
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
  statistics(
    'Statistik',
    'Gespeicherte Spiele, Siege, Legs und Sets der Community.',
    Icons.bar_chart_outlined,
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
  ),
  profile(
    'Community bearbeiten',
    'Name, Profilbild und Bio ändern.',
    Icons.edit_outlined,
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
    this.avatarBase64,
  });
  final String description;
  final String? avatarBase64;
  final ValueChanged<CommunityArea> onSelected;

  @override
  Widget build(BuildContext context) => AdaptiveContentList(
    children: [
      Center(child: CommunityAvatar(base64Image: avatarBase64, radius: 40)),
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
