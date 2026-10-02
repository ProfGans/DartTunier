enum ScorerOpponents {
  players('Spieler', 'Mindestens zwei Spieler hinzufügen.'),
  bots('Bots', 'Mindestens einen Bot hinzufügen.'),
  mixed('Spieler & Bots', 'Mindestens zwei Spieler und einen Bot hinzufügen.');

  const ScorerOpponents(this.label, this.requirement);
  final String label, requirement;

  bool accepts(int humans, int botCount) => switch (this) {
    players => humans >= 2 && botCount == 0,
    bots => humans == 1 && botCount >= 1,
    mixed => humans >= 2 && botCount >= 1,
  };
}
