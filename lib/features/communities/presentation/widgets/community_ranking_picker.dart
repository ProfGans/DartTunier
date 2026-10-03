import 'package:flutter/material.dart';
import '../../data/supabase_community_repository.dart';
import '../../domain/community_ranking.dart';

class CommunityRankingPicker extends StatefulWidget {
  const CommunityRankingPicker({
    super.key,
    required this.communityId,
    required this.selectedIds,
    required this.onChanged,
    this.loadRankings,
  });
  final String communityId;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;
  final Future<List<CommunityRanking>> Function()? loadRankings;
  @override
  State<CommunityRankingPicker> createState() => _CommunityRankingPickerState();
}

class _CommunityRankingPickerState extends State<CommunityRankingPicker> {
  late Future<List<CommunityRanking>> _future = _load();
  Future<List<CommunityRanking>> _load() => Future.sync(
    () =>
        widget.loadRankings?.call() ??
        SupabaseCommunityRepository().loadRankings(widget.communityId),
  );
  @override
  void didUpdateWidget(covariant CommunityRankingPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.communityId != oldWidget.communityId) _future = _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<CommunityRanking>>(
    future: _future,
    builder: (context, snapshot) {
      final rankings = snapshot.data ?? [CommunityRanking.standard];
      final missing = widget.selectedIds.where(
        (id) => !rankings.any((rank) => rank.id == id),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gewertete Ranglisten',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text('Ein Turnier kann für mehrere Ranglisten zählen.'),
          for (final ranking in rankings)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(ranking.name),
              value: widget.selectedIds.contains(ranking.id),
              onChanged: (selected) {
                final next = widget.selectedIds.toSet();
                if (selected == true) {
                  next.add(ranking.id);
                } else {
                  next.remove(ranking.id);
                }
                widget.onChanged(next.toList());
              },
            ),
          if (widget.selectedIds.isEmpty)
            const Text(
              'Keine Rangliste ausgewählt: Dieses Turnier wird nicht gewertet.',
            ),
          if (missing.isNotEmpty)
            const Text(
              'Weitere gespeicherte Zuordnungen bleiben erhalten. Ranglisten erneut laden, um sie zu bearbeiten.',
            ),
          if (snapshot.connectionState != ConnectionState.done)
            const LinearProgressIndicator(),
          if (snapshot.hasError)
            TextButton.icon(
              onPressed: () => setState(() => _future = _load()),
              icon: const Icon(Icons.refresh),
              label: const Text('Weitere Ranglisten erneut laden'),
            ),
        ],
      );
    },
  );
}
