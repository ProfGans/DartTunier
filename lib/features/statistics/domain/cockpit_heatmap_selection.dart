import '../data/scorer_heatmap_repository.dart';
import 'saved_scorer_match.dart';

/// The account-owned match identity, never a display name, scopes private hits.
List<ScorerHeatmapSession> selectProfileHeatmaps(
  List<ScorerHeatmapSession> archive,
  List<SavedScorerMatch> matches,
) {
  final owned = {for (final match in matches) match.id: match};
  return [
    for (final session in archive)
      if (owned[session.id] case final match?)
        ScorerHeatmapSession(
          id: session.id,
          date: match.playedAt,
          names: [match.names[match.playerIndex]],
          complete: session.complete,
          hits: session.hits
              .where((hit) => hit.player == match.playerIndex)
              .toList(),
        ),
  ];
}
