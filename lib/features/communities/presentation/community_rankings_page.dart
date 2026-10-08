import '../../../shared/widgets/sport_menu.dart';
import 'package:flutter/material.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../tournaments/domain/tournament_models.dart';
import '../data/supabase_community_repository.dart';
import '../domain/community.dart';
import '../domain/community_permissions.dart';
import '../domain/community_ranking.dart';
import 'community_ranking_page.dart';
import 'widgets/ranking_rules_dialog.dart';

/// One ranking opens directly; multiple rankings show a selection first.
class CommunityRankingsPage extends StatefulWidget {
  const CommunityRankingsPage({
    super.key,
    required this.community,
    required this.repository,
    required this.permissions,
    required this.members,
    required this.tournaments,
  });
  final Community community;
  final SupabaseCommunityRepository repository;
  final CommunityPermissions permissions;
  final List<CommunityMember> members;
  final List<CreatedTournament> tournaments;

  @override
  State<CommunityRankingsPage> createState() => _CommunityRankingsPageState();
}

class _CommunityRankingsPageState extends State<CommunityRankingsPage> {
  late Future<List<CommunityRanking>> _rankings = widget.repository
      .loadRankings(widget.community.id);
  bool _creating = false;

  Future<void> _settings(CommunityRanking ranking, bool nested) async {
    final result = await showDialog<({bool deleted, int? months})>(context: context,
      builder: (_) => RankingRulesDialog(ranking: ranking));
    if (result == null || !mounted) return;
    try {
      await widget.repository.saveRankingRules(widget.community.id, ranking.id,
        validityMonths: result.months, deleted: result.deleted);
      if (!mounted) return;
      if (nested) Navigator.of(context).pop();
      setState(() => _rankings = widget.repository.loadRankings(widget.community.id));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Änderung fehlgeschlagen. Verbindung und Ranglisten-Rechte prüfen.')));
    }
  }

  Future<void> _create() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _RankingNameDialog(),
    );
    if (name == null || !mounted) return;
    setState(() => _creating = true);
    try {
      final previous = await _rankings;
      final created = await widget.repository.createRanking(
        widget.community.id,
        name,
      );
      if (!mounted) return;
      setState(() => _rankings = Future.value([...previous, created]));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Rangliste konnte nicht erstellt werden. Verbindung, Berechtigung und Namen prüfen.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Widget _ranking(CommunityRanking ranking, {bool showAppBar = false}) =>
      CommunityRankingPage(
        key: ValueKey(ranking.id),
        communityName: ranking.name,
        rankingId: ranking.id,
        validityMonths: ranking.validityMonths,
        onSettings: widget.permissions.allows(CommunityPermission.manageRankings)
            ? () => _settings(ranking, showAppBar) : null,
        communityId: widget.community.id,
        repository: widget.repository,
        canManage: widget.permissions.allows(
          CommunityPermission.manageRankings,
        ),
        members: widget.members,
        tournaments: widget.tournaments,
        showAppBar: showAppBar,
      );

  @override
  Widget build(BuildContext context) => FutureBuilder<List<CommunityRanking>>(
    future: _rankings,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return AdaptiveContentList(
          children: [
            const Text('Ranglisten konnten nicht geladen werden.'),
            FilledButton(
              onPressed: () => setState(() {
                _rankings = widget.repository.loadRankings(widget.community.id);
              }),
              child: const Text('Erneut versuchen'),
            ),
          ],
        );
      }
      final rankings = snapshot.data!;
      return Column(
        children: [
          if (widget.permissions.allows(CommunityPermission.editCommunity))
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: _creating ? null : _create,
                icon: const Icon(Icons.add),
                label: const Text('Rangliste erstellen'),
              ),
            ),
          Expanded(
            child: rankings.length == 1
                ? _ranking(rankings.single)
                : AdaptiveContentList(
                    children: [
                      if (rankings.isEmpty) const Text('Keine Ranglisten vorhanden. Erstelle eine neue Rangliste, um Turniere zu werten.'),
                      Text(
                        'Ranglisten',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SportMenuGroup(
                        title: 'Ranglisten',
                        actions: [
                          for (final ranking in rankings)
                            SportMenuAction(
                              label: ranking.name,
                              icon: Icons.leaderboard_outlined,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      _ranking(ranking, showAppBar: true),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      );
    },
  );
}

class _RankingNameDialog extends StatefulWidget {
  const _RankingNameDialog();
  @override
  State<_RankingNameDialog> createState() => _RankingNameDialogState();
}

class _RankingNameDialogState extends State<_RankingNameDialog> {
  final _name = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _name.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rangliste erstellen'),
    scrollable: true,
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _name,
        autofocus: true,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'Name der Rangliste'),
        validator: (value) =>
            (value ?? '').trim().isEmpty ? 'Bitte einen Namen eingeben.' : null,
        onFieldSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Erstellen')),
    ],
  );
}
