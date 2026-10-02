import 'package:flutter/material.dart';
import '../../../../shared/widgets/adaptive_content.dart';
import '../../../tournaments/data/tournament_storage.dart';
import '../../../tournaments/domain/tournament_models.dart';
import '../../domain/community_permissions.dart';
import '../../../devices/presentation/community_board_assignment_page.dart';

class CommunityTournamentActions extends StatelessWidget {
  const CommunityTournamentActions({
    super.key,
    required this.tournament,
    required this.permissions,
    required this.onChanged,
  });
  final CreatedTournament tournament;
  final CommunityPermissions permissions;
  final VoidCallback onChanged;
  Future<void> _act(BuildContext context, String action) async {
    try {
      if (action == 'devices') {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                CommunityBoardAssignmentPage(tournament: tournament),
          ),
        );
        return;
      }
      if (action == 'edit') {
        final edited = await Navigator.of(context).push<CreatedTournament>(
          MaterialPageRoute(
            builder: (_) => _TournamentSettings(tournament: tournament),
          ),
        );
        if (edited == null) return;
        await TournamentStorage().saveTournament(edited);
      } else {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('${tournament.name} löschen?'),
            content: const Text(
              'Das Community-Turnier wird online gelöscht. Eine Internetverbindung ist erforderlich.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Löschen'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await TournamentStorage().deleteTournament(tournament.id);
      }
      onChanged();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Änderung nicht möglich: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Turnieraktionen',
    onSelected: (action) => _act(context, action),
    itemBuilder: (_) => [
      if (permissions.allows(CommunityPermission.assignDevices))
        const PopupMenuItem(value: 'devices', child: Text('Geräte zuteilen')),
      if (permissions.allows(CommunityPermission.editTournaments))
        const PopupMenuItem(value: 'edit', child: Text('Turnier bearbeiten')),
      if (permissions.allows(CommunityPermission.deleteTournaments))
        const PopupMenuItem(value: 'delete', child: Text('Turnier löschen')),
    ],
  );
}

class _TournamentSettings extends StatefulWidget {
  const _TournamentSettings({required this.tournament});
  final CreatedTournament tournament;
  @override
  State<_TournamentSettings> createState() => _TournamentSettingsState();
}

class _TournamentSettingsState extends State<_TournamentSettings> {
  late final _name = TextEditingController(text: widget.tournament.name);
  late final _boards = TextEditingController(
    text: '${widget.tournament.boardCount}',
  );
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _name.dispose();
    _boards.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Turnier bearbeiten')),
    body: Form(
      key: _form,
      child: AdaptiveContentList(
        children: [
          TextFormField(
            controller: _name,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Turniername'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Bitte einen Namen eingeben.'
                : null,
          ),
          TextFormField(
            controller: _boards,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Anzahl Boards'),
            validator: (value) {
              final n = int.tryParse(value ?? '');
              return n == null || n < 1 || n > 64
                  ? '1 bis 64 Boards eingeben.'
                  : null;
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              Navigator.pop(
                context,
                CreatedTournament.fromJson(
                  widget.tournament.toJson()
                    ..['name'] = _name.text.trim()
                    ..['boardCount'] = int.parse(_boards.text),
                ),
              );
            },
            child: const Text('Lokal speichern'),
          ),
        ],
      ),
    ),
  );
}
