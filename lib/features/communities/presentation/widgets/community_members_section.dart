import '../../../../shared/widgets/sport_menu.dart';
import 'package:flutter/material.dart';

import '../../data/supabase_community_repository.dart';
import '../../domain/community.dart';
import '../../domain/community_member_order.dart';
import '../../domain/community_permissions.dart';
import '../community_member_profile_page.dart';

class CommunityMembersSection extends StatefulWidget {
  const CommunityMembersSection({
    super.key,
    required this.community,
    required this.members,
    required this.repository,
    required this.onChanged,
    this.permissions,
  });
  final Community community;
  final List<CommunityMember> members;
  final SupabaseCommunityRepository repository;
  final VoidCallback onChanged;
  final CommunityPermissions? permissions;

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
                    for (final account in sortedCommunityMembers(
                      widget.members,
                      ownerUserId: widget.community.ownerUserId,
                    ).where((item) => !item.isManual))
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

  Future<void> _remove(CommunityMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${member.displayName} entfernen?'),
        content: Text(
          member.isManual
              ? 'Der manuelle Mitgliedseintrag wird entfernt. Gespeicherte Turnierergebnisse bleiben erhalten.'
              : 'Der Account verliert den Zugriff auf diese Community.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(
        () => member.isManual
            ? widget.repository.access.removeManualMember(
                widget.community.id,
                member.playerProfileId!,
              )
            : widget.repository.access.removeMember(
                widget.community.id,
                member.userId!,
              ),
      );
    }
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
        for (final member in sortedCommunityMembers(
          widget.members,
          ownerUserId: widget.community.ownerUserId,
        ))
          ListTile(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CommunityMemberProfilePage(
                  community: widget.community,
                  member: member,
                  members: widget.members,
                  repository: widget.repository,
                ),
              ),
            ),
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
            trailing:
                (canManage && member.isManual) ||
                    (member.userId != widget.community.ownerUserId &&
                        widget.permissions?.allows(
                              CommunityPermission.removeMembers,
                            ) ==
                            true)
                ? PopupMenuButton<String>(
                    tooltip: 'Mitglied verwalten',
                    enabled: !_busy,
                    onSelected: (action) =>
                        action == 'assign' ? _assign(member) : _remove(member),
                    itemBuilder: (_) => [
                      if (canManage && member.isManual)
                        const PopupMenuItem(
                          value: 'assign',
                          child: SportMenuLabel(
                            label: 'Account zuordnen',
                            icon: Icons.arrow_forward_outlined,
                          ),
                        ),
                      if (member.userId != widget.community.ownerUserId &&
                          widget.permissions?.allows(
                                CommunityPermission.removeMembers,
                              ) ==
                              true)
                        const PopupMenuItem(
                          value: 'remove',
                          child: SportMenuLabel(
                            label: 'Mitglied entfernen',
                            icon: Icons.person_remove_outlined,
                          ),
                        ),
                    ],
                  )
                : const Icon(Icons.chevron_right),
          ),
      ],
    );
  }
}
