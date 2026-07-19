import 'package:flutter/material.dart';

import '../../accounts/application/account_session_store.dart';
import '../../accounts/data/supabase_account_config.dart';
import '../../accounts/data/supabase_account_session_store.dart';
import '../../accounts/domain/account_user.dart';
import '../../tournaments/data/app_database.dart';
import '../../tournaments/domain/tournament_models.dart';
import '../data/supabase_community_repository.dart';
import '../domain/community.dart';

typedef CommunityTournamentCreationBuilder = Widget Function(
  String communityId,
  String communityName,
);
typedef CommunityTournamentRunBuilder = Widget Function(
  CreatedTournament tournament,
);

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
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
                message: 'Communities stehen nur mit einem Online-Account zur '
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
    _communitiesFuture = widget.repository.loadMyCommunities();
  }

  Future<void> _createCommunity() async {
    final result = await showDialog<_CommunityFormResult>(
      context: context,
      builder: (_) => const _CreateCommunityDialog(),
    );
    if (result == null) return;
    await _run(() => widget.repository.createCommunity(
      name: result.name,
      description: result.description,
    ));
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
        SnackBar(content: Text('Community-Aktion fehlgeschlagen: $error')),
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
          return _ErrorView(message: '${snapshot.error}', onRetry: () {
            setState(_reload);
          });
        }
        final communities = snapshot.data ?? const [];
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Hallo ${widget.account.displayName}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
            Text('Meine Communities',
                style: Theme.of(context).textTheme.titleLarge),
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
                    leading: const Icon(Icons.hub_outlined),
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
                    },
                  ),
                ),
          ],
        );
      },
    );
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
  late Future<(List<CommunityMember>, List<CreatedTournament>)> _contentFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _contentFuture = _loadContent();
  }

  Future<(List<CommunityMember>, List<CreatedTournament>)>
  _loadContent() async {
    final members = await widget.repository.loadMembers(widget.community.id);
    final tournaments = await widget.repository.loadTournaments(
      widget.community.id,
    );
    return (members, tournaments);
  }

  Future<void> _createTournament() async {
    final builder = widget.createTournamentBuilder;
    if (builder == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => builder(widget.community.id, widget.community.name),
    ));
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.community.name)),
      body: FutureBuilder<(List<CommunityMember>, List<CreatedTournament>)>(
        future: _contentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(message: '${snapshot.error}');
          }
          final (members, tournaments) = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (widget.community.description.isNotEmpty)
                Text(widget.community.description),
              const SizedBox(height: 12),
              SelectableText('Einladungscode: ${widget.community.inviteCode}'),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: widget.createTournamentBuilder == null
                    ? null
                    : _createTournament,
                icon: const Icon(Icons.emoji_events_outlined),
                label: const Text('Community-Turnier erstellen'),
              ),
              const SizedBox(height: 28),
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
                      onTap: widget.runTournamentBuilder == null
                          ? null
                          : () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(builder: (_) =>
                                    widget.runTournamentBuilder!(tournament)),
                              );
                              if (mounted) setState(_reload);
                            },
                    ),
                  ),
              const SizedBox(height: 28),
              Text('Mitglieder (${members.length})',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final member in members)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(member.displayName),
                  trailing: Text(member.role == 'owner' ? 'Inhaber' : 'Mitglied'),
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
  final _name = TextEditingController();
  final _description = TextEditingController();
  @override
  void dispose() { _name.dispose(); _description.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Community erstellen'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: _name, autofocus: true,
        decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _description, maxLines: 3,
        decoration: const InputDecoration(labelText: 'Beschreibung', border: OutlineInputBorder())),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
      FilledButton(onPressed: () {
        if (_name.text.trim().isNotEmpty) {
          Navigator.pop(context, _CommunityFormResult(_name.text, _description.text));
        }
      }, child: const Text('Erstellen')),
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
  @override
  void dispose() { _code.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Community beitreten'),
    content: TextField(controller: _code, autofocus: true,
      textCapitalization: TextCapitalization.characters,
      decoration: const InputDecoration(labelText: 'Einladungscode', border: OutlineInputBorder())),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
      FilledButton(onPressed: () {
        if (_code.text.trim().isNotEmpty) Navigator.pop(context, _code.text);
      }, child: const Text('Beitreten')),
    ],
  );
}

class _CommunityFormResult {
  const _CommunityFormResult(this.name, this.description);
  final String name;
  final String description;
}

class _SignInNotice extends StatelessWidget {
  const _SignInNotice();
  @override
  Widget build(BuildContext context) => const Center(child: Padding(
    padding: EdgeInsets.all(24),
    child: Text('Melde dich im Hauptmenue an, um Communities zu verwenden.', textAlign: TextAlign.center),
  ));
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 40),
      const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center),
      if (onRetry != null) ...[
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Erneut versuchen')),
      ],
    ]),
  ));
}
