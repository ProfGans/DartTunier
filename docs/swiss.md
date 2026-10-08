# Schweizer System

In der Turniererstellung unter Gruppen als Spieltyp **Schweizer System** wählen.
Eine Gruppe umfasst das gesamte Swiss-Feld; mehrere unabhängige Swiss-Gruppen
und anschließende KO-Etappen sind möglich. Der Turnierformfinder berücksichtigt
Swiss über die Modus-Auswahl, der Entwicklungstester nutzt dieselbe Laufzeit.

## Regeln

- Die Rundenzahl wird vor Beginn festgelegt. Alle bleiben bis zum Ende dabei.
- Gegner mit möglichst ähnlicher Punktzahl; keine Wiederholungspaarungen.
- Bei ungerader Teilnehmerzahl erhält ein möglichst niedrig platzierter Spieler
  ohne bisheriges Freilos ein Freilos. Dafür gibt es 3 Punkte, aber kein
  gespieltes Match und keine Legs.
- Sieg: 3 Punkte; Unentschieden bei gerader Leg-Distanz ohne Sets: 1 Punkt.
- Tabelle: Punkte, Buchholz (Summe der Punkte tatsächlich gespielter Gegner),
  Leg-Differenz, gewonnene Legs, ursprüngliche Startreihenfolge.
- Erst wenn alle Begegnungen einer Runde abgeschlossen sind, werden die
  Paarungen der nächsten Runde festgelegt. Vorziehen innerhalb der laufenden
  Runde ist möglich; zukünftige Runden bleiben gesperrt.
- Eine Ergebnisänderung in einer früheren Runde setzt spätere Paarungen und
  deren Ergebnisse zurück, weil diese von der bisherigen Tabelle abhängen.

Dies ist eine Darts-Adaption der
[Swiss-Grundprinzipien der FIDE](https://handbook.fide.com/chapter/C0403202602),
kein vollständiges oder zertifiziertes FIDE-Dutch-System. Schach-Farbregeln und
die Sonderwertung virtueller Gegner sind nicht enthalten.

Die App begrenzt die Rundenzahl auf `ceil(Teilnehmer / 2)`. Diese konservative
Grenze erhält die Möglichkeit wiederholungsfreier vollständiger Paarungen
unabhängig von bisherigen Ergebnissen; bei ungeraden Feldern wird das Freilos
als zusätzlicher virtueller Gegner betrachtet. Die Paarungssuche bevorzugt
punktnahe Gegner und nutzt Rückwärtssuche statt einer reinen Greedy-Zuteilung.

## Zeitplanung und Speicherung

Die Vorschau spielt die produktive Laufzeit mit repräsentativen Ergebnissen
durch und belegt die vorhandenen Boards. Pro Runde müssen sämtliche
Board-Blöcke beendet sein, bevor die folgende Runde beginnt. Zusätzlich gelten
standardmäßig **5 Minuten Reserve je Rundenwechsel** für unterschiedlich lange
Matches und die neue Auslosung. Einstellbar unter **Swiss-Zeitplanung**.
Die Reserve verändert sich nicht proportional zur Leg-/Set-Distanz.

Beispiel: 8 Spieler, 3 Runden, 25 Minuten pro Match:
- 3 Boards: 3 × 2 Blöcke × 25 Minuten + 2 × 5 Minuten = 160 Minuten.
- 4 Boards: 3 × 1 Block × 25 Minuten + 2 × 5 Minuten = 85 Minuten.

Es bleibt eine Schätzung; einzelne überlange Matches können sie überschreiten.
Paarungen, Ergebnisse und leere zukünftige Slots werden im bestehenden
versionierten Turnierspeicher gespeichert. `groupRoundRobinRepeats` bedeutet
bei `playType: swiss` die Rundenzahl; ältere Spieltypen behalten ihre Bedeutung.
Es sind keine neuen JSON-Pflichtfelder und keine Migration bestehender Turniere
notwendig.
