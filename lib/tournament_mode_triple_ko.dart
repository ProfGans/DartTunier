part of 'main.dart';

const String _tripleFinalLabel = 'Triple-KO Finalrunde';

String _lossLevelBracketLabel(int lossCount) {
  return switch (lossCount) {
    0 => 'Winners Bracket',
    1 => '1 Niederlage Bracket',
    _ => '$lossCount Niederlagen Bracket',
  };
}

String _lossLevelBracketTitle(int lossCount) {
  return switch (lossCount) {
    0 => '0 Niederlagen',
    1 => '1 Niederlage',
    _ => '$lossCount Niederlagen',
  };
}

String _lossLevelMatchLabel(int lossCount, int roundNumber) {
  return '${_lossLevelBracketTitle(lossCount)} Runde $roundNumber';
}
