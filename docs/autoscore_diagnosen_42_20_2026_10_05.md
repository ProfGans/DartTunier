# Videodiagnosen 42 und 20 (2026-10-05)

## Replay und Änderung

Die Originalframes werden in zeitlicher Reihenfolge mit den echten Host-Zeitstempeln
durch den produktiven Controller gespielt. Korrekturwerte sind nur Sollwerte der
Auswertung. Beide Scorefehler waren im aktuellen Code reproduzierbar.

| Fall | Benutzerkorrektur | Vorher | Jetzt |
| --- | --- | --- | --- |
| 42 | T5 | 5 | T5 |
| 20 | 20 | 5 | 20 |

**42:** Die beiden Schaftachsen haben Konfidenzen um 0,99 und 0,95 und schneiden
sich über mehrere Frames im T5. Zwei sichtbare Enden verschieben den geschätzten
Kontakt um wenige Millimeter über den Draht in die Single-5. Die vorhandene
Schutzregel für konsistente Drei-Kamera-Schnitte gilt jetzt auch für zwei
unabhängig sehr starke Schäfte (je mindestens 0,90 Konfidenz): Zwei Endpunkte
allein dürfen deren Score nicht ändern, wenn die dritte Spitzenbestätigung fehlt.

**20:** Die drei entscheidenden Schätzungen lauten 5, 20, 5. Nur die mittlere
wird durch alle drei starken Kameraachsen getragen, deren Residuum 0,127 mm ist.
Die bisherige zeitliche Medoid-Auswahl bevorzugt die zwei falschen Punkte.
Beim begrenzten dritten Entscheidungsschritt erhält eine konsistente Drei-Ansicht-
Schätzung Vorrang vor einer Zwei-Linien-Schätzung. Die verlässliche Unterstützung
wird vor der optionalen Spitzenschätzung erfasst (alle drei Achsen mindestens
0,80 Konfidenz, gemeinsames Residuum höchstens 3 mm) und als `supportingViews`
im Diagnosebericht mitgeführt. Es gibt keine zusätzliche Warteschleife.

## Grenzen

Die Scoreentscheidungen sind repariert. Im Fall 20 liegt der gewählte Punkt
weiterhin ungefähr 25 mm neben der gespeicherten manuellen Position: Der gleiche
Score bedeutet noch keine präzise Spitze in der flachen Ansicht. Der manuelle
Punkt ist keine unabhängig vermessene Referenz. Die optische Kontakt-/Kalibrier-
Genauigkeit dieses Falls bleibt weiter zu untersuchen.

Die beiden Pakete zeigen Fehlentscheidungen, keine reproduzierte Blockade. Die
vorherige Freigabe des Herauszieh-Status wird beibehalten.

## Prüfung

- Zwei neue komplette Original-Video-Regressionsfälle: jeweils genau ein Score,
  weiterhin laufend und nicht im Herauszieh-Wartestatus.
- Zwei Domain-Tests: Deadline-Auswahl mit versus ohne Drei-Ansicht-Unterstützung.
- 251 Autoscoring-Tests bestanden.
- Alle 25 älteren vom Benutzer zuletzt gelieferten Pakete behalten ihre Scores.
- Frühere Videofälle 5, 97 und 126 behalten T1, 20 und T20.
- Keine neuen Analysewarnungen; bestehender Style-Hinweis in
  `test/manual_update_card_test.dart:35`. Windows-Build geprüft.
- Keine neue Live-Wurfserie durchgeführt; Gesamtgenauigkeit von 99,5 % nicht belegt.

Replays: `build/autoscore_analysis/new_42_20_baseline.json`,
`new_42_20_improved.json`, `new_42_20_priorvideos.json`.
Regressionen: `test/autoscore_video_decision_reliability_test.dart`.
