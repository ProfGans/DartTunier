import '../../../../shared/widgets/sport_menu.dart';
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
  calendar(
    'Kalender',
    'Turniertermine, Vorlagen und persönliche Erinnerungen.',
    Icons.calendar_month_outlined,
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
    this.rankingEnabled = true,
  });
  final String description;
  final String? avatarBase64;
  final bool rankingEnabled;
  final ValueChanged<CommunityArea> onSelected;

  @override
  Widget build(BuildContext context) => AdaptiveContentList(
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommunityAvatar(base64Image: avatarBase64, radius: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community-Menü',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(description),
                ],
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      SportMenuGroup(
        title: 'Spieltag',
        actions: [
          for (final area in [
            CommunityArea.tournaments,
            CommunityArea.calendar,
          ])
            _action(area),
        ],
      ),
      SportMenuGroup(
        title: 'Team & Leistung',
        actions: [
          _action(CommunityArea.members),
          if (rankingEnabled) _action(CommunityArea.ranking),
          _action(CommunityArea.statistics),
        ],
      ),
      SportMenuGroup(
        title: 'Community verwalten',
        collapsible: true,
        icon: Icons.admin_panel_settings_outlined,
        actions: [
          for (final area in [
            CommunityArea.invitations,
            CommunityArea.devices,
            CommunityArea.roles,
            CommunityArea.profile,
          ])
            _action(area),
        ],
      ),
    ],
  );

  SportMenuAction _action(CommunityArea area) => SportMenuAction(
    label: area.title,
    icon: area.icon,
    onTap: () => onSelected(area),
  );
}
