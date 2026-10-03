const highlightMaximumScores = [162, 165, 168, 171, 174, 177, 180];
const highlightShortLegDarts = 18;

String highlightCountLabel(Map<int, int> counts, {String unit = ''}) =>
    (counts.keys.toList()..sort())
        .map((value) => '${counts[value]} × $value$unit')
        .join(' · ');
