/// Keep human visits, but never persist a bot's scoring statistics.
Map<String, dynamic>? withoutBotStatistics(
  Map<String, dynamic>? result, Set<int> bots,
) {
  if (result == null || bots.isEmpty) return result;
  final clean = Map<String, dynamic>.from(result);
  final raw = clean['statistics'];
  if (bots.contains(0) && bots.contains(1)) {
    clean.remove('statistics');
  } else if (raw is Map) {
    clean['statistics'] = {
      ...Map<String, dynamic>.from(raw),
      'visits': [for (final v in raw['visits'] as List? ?? const [])
        if (v is Map && !bots.contains(v['player'])) v],
    };
  }
  return clean;
}
