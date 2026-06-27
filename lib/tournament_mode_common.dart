part of 'main.dart';

const String _autoAdvanceLabel = 'Automatisch gesetzt';

int _log2PowerOfTwo(int value) {
  var size = value;
  var exponent = 0;
  while (size > 1) {
    size ~/= 2;
    exponent++;
  }
  return exponent;
}

List<GroupMatch> _matchesWithLabel(
  List<List<GroupMatch>> rounds,
  String label,
) {
  return [
    for (final round in rounds)
      for (final match in round)
        if (match.label == label) match,
  ];
}
