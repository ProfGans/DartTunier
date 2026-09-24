import 'package:flutter/material.dart';

import '../../data/supabase_community_repository.dart';
import '../../domain/community.dart';

class CommunityMembersSection extends StatefulWidget {
  const CommunityMembersSection({
    super.key,
    required this.community,
    required this.members,
    required this.repository,
    required this.onChanged,
  });
  final Community community;
  final List<CommunityMember> members;
  final SupabaseCommunityRepository repository;
  final VoidCallback onChanged;

  @override
  State<CommunityMembersSection> createState() =>
      _CommunityMembersSectionState();
}

class _CommunityMembersSectionState extends State<CommunityMembersSection> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) widget.onChanged();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Mitglied konnte nicht gespeichert werden. Bitte Verbindung und Berechtigung prüfen und erneut versuchen.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    var name = '';
    final form = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mitglied hinzufügen'),
        content: Form(
          key: form,
          child: TextFormField(
            autofocus: true,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Name'),
            onChanged: (value) => name = value.trim(),
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
              if (form.currentState!.validate()) Navigator.pop(context, name);
            },
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    await _run(
      () => widget.repository.addManualMember(widget.community.id, result),
    );
  }

  Future<void> _assign(CommunityMember member) async {
    var selected = member.linkedUserId ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${member.displayName} zuordnen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Account aus dieser Community auswählen. Bisherige Ergebnisse und Ranglistenpunkte werden diesem Account zugerechnet. Die Zuordnung kann später geändert werden.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Ohne Account'),
                    ),
                    for (final account in widget.members.where(
                      (item) => !item.isManual,
                    ))
                      DropdownMenuItem(
                        value: account.userId,
                        child: Text(
                          account.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => selected = value ?? ''),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Zuordnung speichern'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    await _run(
      () => widget.repository.assignManualMember(
        communityId: widget.community.id,
        memberId: member.playerProfileId!,
        userId: result.isEmpty ? null : result,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canManage =
        widget.community.ownerUserId == widget.repository.currentUserId;
    final names = {
      for (final member in widget.members)
        if (!member.isManual) member.userId!: member.displayName,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mitglieder', style: Theme.of(context).textTheme.titleLarge),
        if (canManage)
          OutlinedButton.icon(
            onPressed: _busy ? null : _add,
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Mitglied hinzufügen'),
          ),
        if (_busy) const LinearProgressIndicator(),
        for (final member in widget.members)
          ListTile(
            leading: Icon(
              member.isManual ? Icons.person_outline : Icons.person,
            ),
            title: Text(member.displayName),
            subtitle: Text(
              member.isManual
                  ? member.linkedUserId == null
                        ? 'Manuell · ohne Account'
                        : 'Zugeordnet: ${names[member.linkedUserId] ?? 'Account'}'
                  : member.role == 'owner'
                  ? 'Inhaber'
                  : 'Mitglied mit Account',
            ),
            trailing: canManage && member.isManual
                ? IconButton(
                    tooltip: 'Account zuordnen',
                    icon: const Icon(Icons.link),
                    onPressed: _busy ? null : () => _assign(member),
                  )
                : null,
          ),
      ],
    );
  }
}
