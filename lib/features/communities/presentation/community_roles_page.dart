import '../../../shared/widgets/sport_settings_section.dart';
import 'package:flutter/material.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../data/community_access_repository.dart';
import '../data/supabase_community_repository.dart';
import '../domain/community.dart';
import '../domain/community_permissions.dart';

class CommunityRolesPage extends StatefulWidget {
  const CommunityRolesPage({
    super.key,
    required this.community,
    required this.membersRepository,
    required this.access,
  });
  final Community community;
  final SupabaseCommunityRepository membersRepository;
  final CommunityAccessRepository access;
  @override
  State<CommunityRolesPage> createState() => _CommunityRolesPageState();
}

class _CommunityRolesPageState extends State<CommunityRolesPage> {
  late Future<
    (
      CommunityPermissions,
      List<CommunityRole>,
      List<CommunityMember>,
      Map<String, String>,
    )
  >
  _data = _load();
  bool _busy = false;
  Future<
    (
      CommunityPermissions,
      List<CommunityRole>,
      List<CommunityMember>,
      Map<String, String>,
    )
  >
  _load() async => (
    await widget.access.permissions(widget.community.id),
    await widget.access.roles(widget.community.id),
    await widget.membersRepository.loadMembers(widget.community.id),
    await widget.access.assignments(widget.community.id),
  );
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        setState(() {
          _data = _load();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Änderung nicht möglich. Verbindung und Berechtigungen prüfen.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(CommunityPermissions rights, [CommunityRole? role]) async {
    final result = await Navigator.of(context).push<(String, Set<String>)>(
      MaterialPageRoute(
        builder: (_) => CommunityRoleEditor(grantable: rights, role: role),
      ),
    );
    if (result != null && mounted) {
      await _run(
        () => widget.access.saveRole(
          widget.community.id,
          result.$1,
          result.$2,
          id: role?.id,
        ),
      );
    }
  }

  Future<void> _assign(
    CommunityMember member,
    List<CommunityRole> roles,
    CommunityPermissions rights,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Rolle für ${member.displayName}'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ''),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Nur lesen (keine Rolle)'),
            ),
          ),
          for (final role in roles.where((r) => rights.mayGrant(r.permissions)))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, role.id),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(role.name),
              ),
            ),
        ],
      ),
    );
    if (result != null && mounted) {
      await _run(
        () => widget.access.assign(
          widget.community.id,
          member.userId!,
          result.isEmpty ? null : result,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Rollen & Rechte · ${widget.community.name}')),
    body:
        FutureBuilder<
          (
            CommunityPermissions,
            List<CommunityRole>,
            List<CommunityMember>,
            Map<String, String>,
          )
        >(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _data = _load();
                  }),
                  child: const Text(
                    'Rechte konnten nicht geladen werden · Erneut versuchen',
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final (rights, roles, members, assignments) = snapshot.data!;
            final manage = rights.allows(CommunityPermission.manageRoles);
            return AdaptiveContentList(
              children: [
                const Text(
                  'Der Inhaber hat alle Rechte. Mitglieder ohne Rolle können lesen. Rollen gelten nur in dieser Community; manuelle Spieler und Geräte erhalten keine Account-Rechte.',
                ),
                const SizedBox(height: 16),
                if (manage)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _edit(rights),
                      icon: const Icon(Icons.add),
                      label: const Text('Rolle erstellen'),
                    ),
                  ),
                if (_busy) const LinearProgressIndicator(),
                const SizedBox(height: 16),
                AdaptiveTileLayout(
                  children: [
                    for (final role in roles)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                role.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              SportSettingsSection(
                                title: 'Berechtigungen',
                                summary: role.permissions.isEmpty
                                    ? 'Nur lesen'
                                    : '${role.permissions.length} Rechte freigegeben',
                                icon: Icons.verified_user_outlined,
                                children: [
                                  Text(
                                    role.permissions.isEmpty
                                        ? 'Nur lesen'
                                        : CommunityPermission.values
                                              .where(
                                                (p) => role.permissions
                                                    .contains(p.key),
                                              )
                                              .map((p) => p.label)
                                              .join('\n'),
                                  ),
                                ],
                              ),
                              if (rights.mayGrant(role.permissions))
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _edit(rights, role),
                                  child: const Text('Rolle bearbeiten'),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Rollen zuweisen',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final member in members.where((m) => !m.isManual))
                  Card(
                    child: ListTile(
                      title: Text(member.displayName),
                      subtitle: Text(
                        member.userId == widget.community.ownerUserId
                            ? 'Inhaber · alle Rechte'
                            : roles
                                      .where(
                                        (r) =>
                                            r.id == assignments[member.userId],
                                      )
                                      .map((r) => r.name)
                                      .firstOrNull ??
                                  'Nur lesen',
                      ),
                      trailing:
                          manage &&
                              member.userId != widget.community.ownerUserId
                          ? IconButton(
                              tooltip: 'Rolle zuweisen',
                              icon: const Icon(Icons.manage_accounts),
                              onPressed: _busy
                                  ? null
                                  : () => _assign(member, roles, rights),
                            )
                          : null,
                    ),
                  ),
              ],
            );
          },
        ),
  );
}

class CommunityRoleEditor extends StatefulWidget {
  const CommunityRoleEditor({super.key, required this.grantable, this.role});
  final CommunityPermissions grantable;
  final CommunityRole? role;
  @override
  State<CommunityRoleEditor> createState() => _CommunityRoleEditorState();
}

class _CommunityRoleEditorState extends State<CommunityRoleEditor> {
  late final _name = TextEditingController(text: widget.role?.name ?? '');
  late final _selected = {...?widget.role?.permissions};
  static const _permissionGroups = {
    'Turniere': [
      CommunityPermission.createTournaments,
      CommunityPermission.editTournaments,
      CommunityPermission.leadTournaments,
      CommunityPermission.deleteTournaments,
    ],
    'Community & Mitglieder': [
      CommunityPermission.inviteMembers,
      CommunityPermission.removeMembers,
      CommunityPermission.editCommunity,
      CommunityPermission.manageRoles,
    ],
    'Geräte, Ranglisten & Highlights': [
      CommunityPermission.assignDevices,
      CommunityPermission.manageRankings,
      CommunityPermission.manageHighlights,
    ],
  };
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.role == null ? 'Rolle erstellen' : 'Rolle bearbeiten'),
    ),
    body: Form(
      key: _form,
      child: AdaptiveContentList(
        children: [
          TextFormField(
            controller: _name,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Rollenname'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Bitte einen Namen eingeben.'
                : null,
          ),
          const SizedBox(height: 16),
          for (final group in _permissionGroups.entries)
            SportSettingsSection(
              title: group.key,
              summary:
                  '${group.value.where((p) => _selected.contains(p.key)).length} von ${group.value.length} Rechten ausgewählt',
              icon: Icons.verified_user_outlined,
              children: [
                AdaptiveTileLayout(
                  children: [
                    for (final permission in group.value)
                      CheckboxListTile(
                        title: Text(permission.label),
                        value: _selected.contains(permission.key),
                        onChanged: widget.grantable.allows(permission)
                            ? (checked) => setState(() {
                                if (checked == true) {
                                  _selected.add(permission.key);
                                } else {
                                  _selected.remove(permission.key);
                                }
                              })
                            : null,
                      ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              if (_form.currentState!.validate() &&
                  widget.grantable.mayGrant(_selected)) {
                Navigator.pop(context, (_name.text.trim(), _selected));
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    ),
  );
}
