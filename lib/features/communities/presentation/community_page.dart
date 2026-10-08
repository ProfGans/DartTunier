import 'community_rankings_page.dart';
import '../../community_calendar/domain/community_calendar.dart';
import '../../community_calendar/presentation/community_calendar_page.dart';
export 'community_ranking_page.dart';
export 'community_ranking_history_page.dart';
import 'package:dart_tournament_manager/shared/widgets/adaptive_content.dart';
import 'package:flutter/material.dart';
import '../domain/community_statistics.dart';
import 'community_statistics_page.dart';

import '../../accounts/application/account_session_store.dart';
import '../../accounts/data/supabase_account_config.dart';
import '../../accounts/data/supabase_account_session_store.dart';
import '../../accounts/domain/account_user.dart';
import '../../tournaments/data/app_database.dart';
import '../../tournaments/data/tournament_storage.dart';
import '../../tournaments/domain/tournament_models.dart';
import '../data/supabase_community_repository.dart';
import '../domain/community.dart';

import '../domain/community_invitation.dart';
import 'widgets/community_invitation_section.dart';
import 'community_roles_page.dart';
import 'community_profile_page.dart';
import 'widgets/community_avatar.dart';
import 'widgets/community_tournament_actions.dart';
import 'community_tournament_import_page.dart';
import 'challonge_import_page.dart';
import 'challonge_archive_page.dart';
import '../domain/community_permissions.dart';
import 'widgets/community_members_section.dart';
import 'widgets/community_menu.dart';
import 'widgets/community_permission_gate.dart';
import '../../devices/presentation/community_devices_section.dart';

typedef CommunityTournamentCreationBuilder =
    Widget Function(String communityId, String communityName, {CommunityTournamentPreset? preset, String? title});
typedef CommunityTournamentRunBuilder =
    Widget Function(CreatedTournament tournament);

class CommunityPage extends StatefulWidget {
  const CommunityPage({
    super.key,
    this.createTournamentBuilder,
    this.runTournamentBuilder,
    AccountSessionStore? accountStore,
    SupabaseCommunityRepository? repository,
    LocalAppDatabase? database,
  }) : _accountStore = accountStore,
       _repository = repository,
       _database = database;

  final CommunityTournamentCreationBuilder? createTournamentBuilder;
  final CommunityTournamentRunBuilder? runTournamentBuilder;
  final AccountSessionStore? _accountStore;
  final SupabaseCommunityRepository? _repository;
  final LocalAppDatabase? _database;

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  late final AccountSessionStore _accountStore;
  late Future<AccountUser?> _accountFuture;

  @override
  void initState() {
    super.initState();
    _accountStore =
        widget._accountStore ??
        (SupabaseAccountConfig.isConfigured
            ? SupabaseAccountSessionStore()
            : LocalAccountSessionStore(widget._database ?? LocalAppDatabase()));
    _accountFuture = _accountStore.loadCurrentAccount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Communities'),
      ),
      body: SafeArea(
        child: FutureBuilder<AccountUser?>(
          future: _accountFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorView(message: '${snapshot.error}');
            }
            final account = snapshot.data;
            if (account == null) {
              return const _SignInNotice();
            }
            if (!SupabaseAccountConfig.isConfigured &&
                widget._repository == null) {
              return const _ErrorView(
                message:
                    'Communities stehen nur mit einem Online-Account zur '
                    'Verfuegung.',
              );
            }
            return _CommunityOverview(
              account: account,
              repository: widget._repository ?? SupabaseCommunityRepository(),
              createTournamentBuilder: widget.createTournamentBuilder,
              runTournamentBuilder: widget.runTournamentBuilder,
            );
          },
        ),
      ),
    );
  }
}

class _CommunityOverview extends StatefulWidget {
  const _CommunityOverview({
    required this.account,
    required this.repository,
    required this.createTournamentBuilder,
    required this.runTournamentBuilder,
  });

  final AccountUser account;
  final SupabaseCommunityRepository repository;
  final CommunityTournamentCreationBuilder? createTournamentBuilder;
  final CommunityTournamentRunBuilder? runTournamentBuilder;

  @override
  State<_CommunityOverview> createState() => _CommunityOverviewState();
}

class _CommunityOverviewState extends State<_CommunityOverview> {
  late Future<List<Community>> _communitiesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _communitiesFuture = widget.repository.loadMyCommunities().timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw StateError(
        'Der Community-Server antwortet nicht. Bitte pruefe die Verbindung '
        'und versuche es erneut.',
      ),
    );
  }

  Future<void> _createCommunity() async {
    final result = await showDialog<_CommunityFormResult>(
      context: context,
      builder: (_) => const _CreateCommunityDialog(),
    );
    if (result == null) return;
    await _run(
      () => widget.repository.createCommunity(
        name: result.name,
        description: result.description,
        rankingEnabled: result.rankingEnabled,
      ),
    );
  }

  Future<void> _joinCommunity() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _JoinCommunityDialog(),
    );
    if (code == null) return;
    await _run(() => widget.repository.joinCommunity(code));
  }

  Future<void> _run(Future<Object> Function() action) async {
    try {
      await action();
      if (!mounted) return;
      setState(_reload);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(days: 1),
          content: SelectableText('Community-Aktion fehlgeschlagen: $error'),
          action: SnackBarAction(
            label: '✕',
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Community>>(
      future: _communitiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorView(
            message: _communityErrorMessage(snapshot.error!),
            onRetry: () {
              setState(_reload);
            },
          );
        }
        final communities = snapshot.data ?? const [];
        return AdaptiveContentList(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Hallo ${widget.account.displayName}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Erstellt Communities oder tretet mit einem Einladungscode bei.',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _createCommunity,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Community erstellen'),
                ),
                OutlinedButton.icon(
                  onPressed: _joinCommunity,
                  icon: const Icon(Icons.login_outlined),
                  label: const Text('Mit Code beitreten'),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Meine Communities',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (communities.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Du bist noch in keiner Community.'),
                ),
              )
            else
              for (final community in communities)
                Card(
                  child: ListTile(
                    leading: CommunityAvatar(
                      base64Image: community.avatarBase64,
                    ),
                    title: Text(community.name),
                    subtitle: community.description.isEmpty
                        ? null
                        : Text(community.description),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CommunityDetailPage(
                            community: community,
                            repository: widget.repository,
                            createTournamentBuilder:
                                widget.createTournamentBuilder,
                            runTournamentBuilder: widget.runTournamentBuilder,
                          ),
                        ),
                      );
                      if (mounted) setState(_reload);
                    },
                  ),
                ),
          ],
        );
      },
    );
  }

  String _communityErrorMessage(Object error) {
    final errorText = error.toString().toLowerCase();
    if (errorText.contains('host is unknown') ||
        errorText.contains('failed host lookup') ||
        errorText.contains('authretryablefetchexception')) {
      return 'Der Community-Server ist nicht erreichbar. Bitte pruefe die '
          'Supabase-Adresse oder deine Internetverbindung.';
    }
    return '$error';
  }
}

class CommunityDetailPage extends StatefulWidget {
  const CommunityDetailPage({
    super.key,
    required this.community,
    required this.repository,
    this.createTournamentBuilder,
    this.runTournamentBuilder,
  });
  final Community community;
  final SupabaseCommunityRepository repository;
  final CommunityTournamentCreationBuilder? createTournamentBuilder;
  final CommunityTournamentRunBuilder? runTournamentBuilder;
  @override
  State<CommunityDetailPage> createState() => _CommunityDetailPageState();
}

class _CommunityDetailPageState extends State<CommunityDetailPage> {
  late Community community = widget.community;
  SupabaseCommunityRepository get repository => widget.repository;
  CommunityTournamentCreationBuilder? get createTournamentBuilder =>
      widget.createTournamentBuilder;
  CommunityTournamentRunBuilder? get runTournamentBuilder =>
      widget.runTournamentBuilder;
  Future<void> _editProfile() async {
    final updated = await Navigator.of(context).push<Community>(
      MaterialPageRoute(
        builder: (_) => CommunityPermissionGate(
          communityId: community.id,
          permission: CommunityPermission.editCommunity,
          repository: repository.access,
          builder: (_) => CommunityProfilePage(
            community: community,
            repository: repository,
          ),
        ),
      ),
    );
    if (updated != null && mounted) setState(() => community = updated);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(community.name),
    ),
    body: CommunityMenu(
      rankingEnabled: community.rankingEnabled,
      description: community.description,
      avatarBase64: community.avatarBase64,
      onSelected: (area) {
        if (area == CommunityArea.profile) {
          _editProfile();
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _CommunitySectionPage(
              community: community,
              repository: repository,
              area: area,
              createTournamentBuilder: createTournamentBuilder,
              runTournamentBuilder: runTournamentBuilder,
            ),
          ),
        );
      },
    ),
  );
}

class _CommunitySectionPage extends StatefulWidget {
  const _CommunitySectionPage({
    required this.community,
    required this.repository,
    required this.area,
    this.createTournamentBuilder,
    this.runTournamentBuilder,
  });

  final Community community;
  final CommunityArea area;
  final SupabaseCommunityRepository repository;
  final CommunityTournamentCreationBuilder? createTournamentBuilder;
  final CommunityTournamentRunBuilder? runTournamentBuilder;

  @override
  State<_CommunitySectionPage> createState() => _CommunitySectionPageState();
}

class _CommunitySectionPageState extends State<_CommunitySectionPage> {
  CommunityPermissions _rights = CommunityPermissions([]);
  late Future<(List<CommunityMember>, List<CreatedTournament>)> _contentFuture;

  @override
  void initState() {
    super.initState();
    if (widget.area != CommunityArea.devices &&
        widget.area != CommunityArea.calendar &&
        widget.area != CommunityArea.invitations &&
        widget.area != CommunityArea.roles) {
      _reload();
    }
  }

  void _reload() {
    _contentFuture = _loadContent();
  }

  Future<(List<CommunityMember>, List<CreatedTournament>)>
  _loadContent() async {
    _rights = await widget.repository.access.permissions(widget.community.id);
    final members = widget.area == CommunityArea.tournaments
        ? <CommunityMember>[]
        : await widget.repository.loadMembers(widget.community.id);
    final tournaments = widget.area == CommunityArea.members
        ? <CreatedTournament>[]
        : await widget.repository.loadTournaments(widget.community.id);
    return (members, tournaments);
  }

  Future<void> _createTournament() async {
    final builder = widget.createTournamentBuilder;
    if (builder == null ||
        !_rights.allows(CommunityPermission.createTournaments)) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => builder(widget.community.id, widget.community.name),
      ),
    );
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final title = '${widget.area.title} · ${widget.community.name}';
    if (widget.area == CommunityArea.calendar) {
      return CommunityCalendarPage(
        communityId: widget.community.id, communityName: widget.community.name,
        loadPermissions: () => widget.repository.access.permissions(widget.community.id),
        createTournament: widget.createTournamentBuilder == null ? null : (preset, title) =>
          widget.createTournamentBuilder!(widget.community.id,widget.community.name,preset: preset,title: title),
      );
    }
    if (widget.area == CommunityArea.roles) {
      return CommunityRolesPage(
        community: widget.community,
        membersRepository: widget.repository,
        access: widget.repository.access,
      );
    }
    if (widget.area == CommunityArea.devices ||
        widget.area == CommunityArea.invitations) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: AdaptiveContentList(
          children: [
            if (widget.area == CommunityArea.devices)
              CommunityDevicesSection(communityId: widget.community.id)
            else
              CommunityInvitationSection(
                communityId: widget.community.id,
                access: widget.repository.access,
              ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<(List<CommunityMember>, List<CreatedTournament>)>(
        future: _contentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(
              message: '${snapshot.error}',
              onRetry: () => setState(_reload),
            );
          }
          final (members, tournaments) = snapshot.data!;
          if (widget.area == CommunityArea.statistics) {
            return CommunityStatisticsMenu(
              communityName: widget.community.name,
              data: CommunityStatistics(communityId: widget.community.id,
                members: members, tournaments: tournaments),
            );
          }
          if (widget.area == CommunityArea.ranking) {
            return CommunityRankingsPage(
              community: widget.community,
              repository: widget.repository,
              permissions: _rights,
              members: members,
              tournaments: tournaments,
            );
          }
          if (widget.area == CommunityArea.members) {
            return AdaptiveContentList(
              children: [
                CommunityMembersSection(
                  community: widget.community,
                  members: members,
                  repository: widget.repository,
                  permissions: _rights,
                  onChanged: () => setState(_reload),
                ),
              ],
            );
          }
          return AdaptiveContentList(
            padding: const EdgeInsets.all(24),
            children: [
              FilledButton.icon(
                onPressed:
                    widget.createTournamentBuilder == null ||
                        !_rights.allows(CommunityPermission.createTournaments)
                    ? null
                    : _createTournament,
                icon: const Icon(Icons.emoji_events_outlined),
                label: const Text('Community-Turnier erstellen'),
              ),
              if (_rights.allows(CommunityPermission.createTournaments))
                OutlinedButton.icon(
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Lokales Turnier importieren'),
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute<bool>(builder: (_) => CommunityTournamentImportPage(
                      community: widget.community, repository: widget.repository)));
                    if (mounted) setState(_reload);
                  },
                ),
              if (_rights.allows(CommunityPermission.createTournaments))
                OutlinedButton.icon(
                  icon: const Icon(Icons.history),
                  label: const Text('Challonge-Turniere importieren'),
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => ChallongeImportPage(community: widget.community, repository: widget.repository)));
                    if (mounted) setState(_reload);
                  },
                ),
              const SizedBox(height: 20),
              ValueListenableBuilder<String>(
                valueListenable: TournamentStorage.syncStatus,
                builder: (context, status, _) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(status),
                  subtitle: const Text(
                    'Änderungen werden zuerst lokal gespeichert und bei geöffneter App alle zwei Minuten synchronisiert, beim Turnierabschluss sofort. Ohne Verbindung bleiben sie lokal und werden später erneut übertragen. Manuelle Synchronisierung ist jederzeit möglich.',
                  ),
                  trailing: IconButton(
                    tooltip: 'Jetzt synchronisieren',
                    icon: const Icon(Icons.sync),
                    onPressed: () async {
                      await TournamentStorage().synchronize();
                      if (mounted) setState(_reload);
                    },
                  ),
                ),
              ),
              Text('Turniere', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (tournaments.isEmpty)
                const Text('Noch keine Turniere in dieser Community.')
              else
                for (final tournament in tournaments)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.emoji_events_outlined),
                      title: Text(tournament.name),
                      subtitle: Text('${tournament.players.length} Spieler'),
                      trailing:
                          _rights.allows(CommunityPermission.createTournaments) ||
                          _rights.allows(CommunityPermission.assignDevices) ||
                              _rights.allows(
                                CommunityPermission.editTournaments,
                              ) ||
                              _rights.allows(
                                CommunityPermission.deleteTournaments,
                              )
                          ? CommunityTournamentActions(
                              tournament: tournament,
                              permissions: _rights,
                              onChanged: () => setState(_reload),
                            )
                          : null,
                      onTap:
                          tournament.importedArchive != null
                          ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => ChallongeArchivePage(tournament: tournament)))
                          : widget.runTournamentBuilder == null
                          ? null
                          : () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      widget.runTournamentBuilder!(tournament),
                                ),
                              );
                              if (mounted) setState(_reload);
                            },
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _CreateCommunityDialog extends StatefulWidget {
  const _CreateCommunityDialog();
  @override
  State<_CreateCommunityDialog> createState() => _CreateCommunityDialogState();
}

class _CreateCommunityDialogState extends State<_CreateCommunityDialog> {
  bool _rankingEnabled = true;
  final _name = TextEditingController();
  final _description = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Community erstellen'),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Beschreibung',
            border: OutlineInputBorder(),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Rangliste aktivieren'),
          subtitle: const Text('Mit Elo-Rangliste spielen. Später in den Community-Einstellungen änderbar.'),
          value: _rankingEnabled,
          onChanged: (value) => setState(() => _rankingEnabled = value),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        onPressed: () {
          if (_name.text.trim().isNotEmpty) {
            Navigator.pop(
              context,
              _CommunityFormResult(_name.text, _description.text, _rankingEnabled),
            );
          }
        },
        child: const Text('Erstellen'),
      ),
    ],
  );
}

class _JoinCommunityDialog extends StatefulWidget {
  const _JoinCommunityDialog();
  @override
  State<_JoinCommunityDialog> createState() => _JoinCommunityDialogState();
}

class _JoinCommunityDialogState extends State<_JoinCommunityDialog> {
  final _code = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Community beitreten'),
    content: TextField(
      controller: _code,
      autofocus: true,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(
        labelText: 'Einladungscode oder Link',
        errorText: _error,
        border: const OutlineInputBorder(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        onPressed: () {
          final code = CommunityInvitation.parseInput(_code.text);
          if (code != null) {
            Navigator.pop(context, code);
          } else {
            setState(
              () => _error =
                  'Bitte einen gültigen Code oder Einladungslink eingeben.',
            );
          }
        },
        child: const Text('Beitreten'),
      ),
    ],
  );
}

class _CommunityFormResult {
  const _CommunityFormResult(this.name, this.description, this.rankingEnabled);
  final String name;
  final String description;
  final bool rankingEnabled;
}

class _SignInNotice extends StatelessWidget {
  const _SignInNotice();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Melde dich im Hauptmenue an, um Communities zu verwenden.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40),
          const SizedBox(height: 12),
          SelectableText(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Erneut versuchen'),
            ),
          ],
        ],
      ),
    ),
  );
}

