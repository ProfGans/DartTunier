# Scorer

Eigenständiger Feature-Bereich unter `lib/features/scorer`, erreichbar über das
Hauptmenü. Aktuell X01 als freies Spiel mit Menschen und Bots; keine automatische
Ergebnisübertragung zu Turnieren und keine Speicherung laufender Partien.

## Übernahme aus der bisherigen App

Quelle: `C:/Users/johan/Desktop/Dart/flutter_app`.
Übernommen wurden X01-Modelle, Regeln, Aufnahme-Engine, Checkout-Bewertung,
Board-Geometrie und Bot-Engine sowie deren vorberechnete Setup-Routen.
Die alte Debug-Infrastruktur wurde durch einen optionalen Logging-Callback ersetzt.
Die alte App wurde nicht verändert.

Die neue Oberfläche übernimmt freie Startpunkte, individuelle Startpunkte,
Straight/Double In, Single/Double/Master Out, Legs/Sets, mehrere Teilnehmer,
Anwerfer-Auswahl und getrennte Bot-Stärken für Scoring und Finish (1–1000).
Ausbullen erfolgt am Board; das Ergebnis wird als Anwerfer ausgewählt.
Cricket, Bob's 27, Karriere und alte Spielerdatenbank
sind nicht Teil dieses X01-Moduls.

## Begriffe und Formate

„Scorer“ ist der Menübereich, „X01“ der Spielmodus. „Best of Legs“ und „Best of
Sets“ entsprechen der Benennung in `TournamentGameFormat`. Die ScorerSettings
rechnen Best of N explizit in N ~/ 2 + 1 benötigte Siege um. Ein Set bedeutet
Leg-Zählweise. Im freien Spiel sind nur ungerade Best-of-Werte erlaubt; die
Turnierfunktion für Unentschieden wird dadurch nicht verändert.

## Checkouttabelle

`data/fixed_checkout_labels.dart` enthält feste, eindeutige Wege für Rest 1–180,
1–3 Darts und alle drei Out-Regeln, jeweils bis zu fünf. Bei weniger möglichen
Wegen werden keine Duplikate oder unmöglichen Wege ergänzt (170 Double Out: einer).
Der Rechner und die bevorzugten Bot-Finishes lesen die Tabelle ohne Routensuche.
Die übrige Bot-Strategie nutzt weiterhin die übernommenen Setup-/Leave-Regeln.

Die Tabelle wird ausschließlich bei Entwicklung mit
`dart run tool/generate_scorer_checkouts.dart` neu erzeugt. Sie verwendet die
übernommene Balanced-Bewertung und ein deterministisches Tie-Breaking. Das
Bot-Setup-Asset ist separat als Schema-Version 2 registriert.

## Taschenrechner und Bot-Einstellungen

Der Scorer erfasst die Summe einer Aufnahme (0–180) über einen Zahlenblock nach
dem Vorbild der alten App. Schnelltasten 26/41/60/81/100/140 sowie 180 füllen die
Eingabe; OK bestätigt. C löscht die Eingabe, Rücktaste eine Ziffer. Enter bestätigt
auch über die Tastatur. CHECK öffnet bei gültigem Rest die Checkout-Bestätigung
mit der Anzahl geworfener Darts. Double In wird bei erstmaliger Punktaufnahme
bestätigt. Unmögliche Aufnahmesummen und Checkouts werden zurückgewiesen.
Rückgängig nimmt eine menschliche Aufnahme samt nachfolgenden Botwürfen zurück.

„Gegen Bot spielen“ wählt einen Bot als Gegner. Unter „Einstellungen → Scorer &
Bots“ oder direkt im Scorer sind Scoring-/Checkout-Stärke, Zielstreuung,
Simulationsstreuung und Wurftempo einstellbar. Die Prozentumrechnung übernimmt
die Kalibrierung der ursprünglichen App (Settings v9). Einstellungen gelten für
neue Spiele und liegen in `scorer_bot_settings.json` mit eigener Schema-Version 2.
Die bestehenden Turnier- und Einstellungsformate werden nicht verändert.
Diese separate Datei ist noch nicht Bestandteil der bisherigen Backup-Dateiliste.

### Theo-Average

Die Bot-Stärke kann wie in der anderen App über den theoretischen 3-Dart-Average
eingestellt werden, sowohl als gespeicherte Vorgabe als auch pro Gegner.
Dezimalkomma und Dezimalpunkt sind erlaubt, beispielsweise `60,5`.
Die übernommene Theo-Tabelle liefert bei passender Kalibrierung für 35–120
direkt Scoring-/Finishing-Skillpaare in 0,1-Schritten. Außerhalb der Tabelle
ermittelt die übernommene Suche mit der Bot-Engine das nächstpassende Profil im
Hintergrund. Der angegebene Average ist ein theoretischer Richtwert, kein
garantierter Match-Average. Die erweiterten Streuungseinstellungen werden bei
der Umrechnung berücksichtigt.

Schema v1 wird beim Laden übernommen: vorhandene manuelle Skillwerte bleiben
aktiv, bis „Stärke über Theo-Average“ eingeschaltet wird. Neue Einstellungen
verwenden standardmäßig Theo-Average 60. Die Berechnungsergebnisse werden pro
Average und Kalibrierung im Arbeitsspeicher wiederverwendet.

`flutter test test/scorer_theo_test.dart` prüft Originaltabellen-Zuordnung,
Fallback-Suche, Migration, Komma-Eingabe, Speichern und Bot-Profile beim Start.

## Matchstatistik

Das Diagrammsymbol im Scorer öffnet die neue Live-/Spielauswertung mit Averages,
Checkoutquote, hohen Aufnahmen, Finishes, Legs, Breaks/Holds und Leg-Verlauf.
Definitionen, Recherchequellen und Zählkonventionen stehen in
[dart_statistics.md](dart_statistics.md). Die Statistik gilt für die geöffnete
Partie; eine dauerhafte Matchhistorie ist noch nicht angebunden.

## Prüfung der Eingabe und Statistik

`flutter test test/scorer_visit_entry_test.dart test/scorer_widget_test.dart`
prüft Aufnahme-Eingabe, Double In, Checkoutanzahl, Bot-Kalibrierung, Persistenz,
den kompletten Bot-Spielstart und das Zahlenfeld auf einem schmalen Bildschirm.

`flutter test test/scorer_test.dart` prüft Best-of-Umrechnung, Bust, Double In,
Leg-/Setwechsel, Undo, Botspiel und sämtliche festen Checkoutwege.
Der bestehende Turnier-Matrix-Test bleibt der Regressionstest der Turnierverwaltung.

`flutter test test/scorer_statistics_test.dart` prüft Berechnung, Undo und Anzeige.
