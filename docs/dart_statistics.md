# Dart-Statistiken im X01-Scorer

Recherche: 30.09.2026. Umsetzung für die laufende Partie und ihre abschließende
Spielauswertung. Keine spielübergreifende Speicherung oder Ableitung aus alten
Turnierergebnissen: Dort fehlen die benötigten Aufnahmen und Dartanzahlen.

## Quellen und Auswahl

- [DartCounter: Statistics](https://dartcounter.net/darts-manual/dartcounter-statistics):
  nennt Average, First 9, Checkoutquote und Darts pro Leg als zentrale Messwerte.
- [Autodarts: Statistics](https://docs.autodarts.com/statistics/stats-page/):
  dokumentiert 3DA, First 9, Legs sowie hohe Aufnahmen als Auswertungsbereiche.
- [DartConnect: How To](https://www.dartconnect.com/how-to/):
  beschreibt die Erfassung von Miss/Bust und die Bedeutung der tatsächlichen
  Checkout-Dartanzahl für den Average.
- [Winmau: Premier League Night 11](https://winmau.com/blogs/news/superchin-earns-draw-in-liverpool-premier-league-night-11):
  Beispiel zur Checkoutquote mit fünf Treffern bei sechs Darts auf Doppel.

## Implementierte Definitionen

| Kennzahl | Berechnung |
| --- | --- |
| 3-Dart-Average | Summe gewerteter Punkte / Summe Statistik-Darts × 3 |
| First-9-Average | Gewertete Punkte aus den ersten drei Aufnahmen je Leg / zugehörige Statistik-Darts × 3 |
| Checkoutquote | Gewonnene Legs / tatsächlich erfasste Versuche auf ein beendendes Doppel oder Bull × 100; nur Double Out |
| Hohe Aufnahmen | Inklusive Schwellen 60+, 100+, 140+ und separat exakt 180 |
| Höchste Aufnahme | Maximum der gewerteten Aufnahmesummen |
| Höchstes Finish | Höchste Restpunktzahl vor einer erfolgreichen Checkout-Aufnahme |
| 100+-Finishes | Erfolgreiche Checkout-Aufnahmen mit mindestens 100 Punkten |
| Bestes Leg | Wenigste Statistik-Darts für ein selbst gewonnenes Leg |
| Darts je gewonnenem Leg | Summe Statistik-Darts in gewonnenen Legs / gewonnene Legs |
| Break / Hold | Leg gegen / mit dem Anwurf gewonnen; nur bei zwei Teilnehmern |
| 9-Darter | Gewonnenes Leg von 501 in neun Statistik-Darts, Straight In / Double Out |
| Legs | Über alle Sets hinweg beendete und selbst gewonnene Legs |
| Busts | Anzahl überworfenener Aufnahmen |

## Bewusste Zählkonventionen

- Jede nicht beendende Aufnahme zählt als drei Statistik-Darts, auch ein früher
  Bust. Ein Bust liefert null Punkte. Dies ist die hier verwendete einheitliche
  Konvention für Menschen und Bots; die Anzahl tatsächlich geworfener Bust-Darts
  kann geringer sein und wird nicht als solche ausgegeben.
- Bei Checkouts zählt die bestätigte Dartanzahl, bei Bots die beobachtete Anzahl.
- First 9 beginnt pro Leg neu. Bei früherem Legende zählen nur vorhandene
  Aufnahmen/Darts. Match-Averages werden aus Summen berechnet, nicht aus dem
  ungewichteten Mittel von Leg-Averages.
- Vor dem Eröffnungsdoppel geworfene Darts bei Double In zählen ebenfalls zum
  Average; ihre Punkte zählen nicht. Eröffnungsversuche sind keine Checkoutversuche.
- Checkoutversuche lassen sich nicht zuverlässig aus einer Aufnahmesumme oder
  der Anzahl der Finishgelegenheiten ableiten. Deshalb gibt der Mensch sie bei
  möglichen Double-Out-Finishes an. „Nicht erfasst“ erzeugt eine Datenlücke:
  die gesamte Checkoutquote wird dann als unvollständig gekennzeichnet.
- Ist bei einem erfolgreichen Finish höchstens ein Checkoutversuch möglich,
  ist ein Treffer/Versuch eindeutig und wird automatisch erfasst.
- Bots zählen anhand der Zielentscheidung, ob der Dart das Leg bei Treffer
  beendet hätte. Ein Wurf auf irgendein Doppel zählt nicht automatisch.
- Fehlende Werte werden als „—“ gezeigt. Die Statistik umfasst nur abgeschlossene
  Aufnahmen; ein gerade laufender Botzug wird nach Ende seiner Aufnahme ergänzt.
- Rückgängig stellt Punkte, Leg-/Setstand, Checkoutversuche und Statistik gemeinsam
  wieder her. Der Leg-Verlauf bleibt auch bei Setwechseln zusammenhängend.

## Zugriff und Tests

Das Diagrammsymbol in der Scorer-Titelleiste öffnet die Vergleichstabelle. Unter
dem Spielfeld führt „Live-Statistik“ beziehungsweise „Spielauswertung ansehen“
zur selben Ansicht. Während die Statistik geöffnet ist, pausiert der Bot.
Die Spieleranzeige enthält zusätzlich den aktuellen 3-Dart-Average.

`flutter test test/scorer_statistics_test.dart` prüft unter anderem 9-Darter,
gewichtete Averages, First 9, Dartanzahl, Busts, Datenlücken, Break/Hold,
Setwechsel, Undo sowie Eingabedialog und schmale Bildschirme.
