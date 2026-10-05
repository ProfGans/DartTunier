# Prüfung der Vor-Update-Diagnosen 183, 173 und 92

Geprüft am 05.10.2026 mit der aktuellen produktiven Erkennung.

| Fall | Damals erkannt | Gespeicherte Korrektur | Jetzt erkannt | Ergebnis |
| --- | --- | --- | --- | --- |
| 183 | 1 | 20 | 1 | weiterhin falsch |
| 173 | 20 | 5 | 20 | weiterhin falsch |
| 92 | 19 | 3 | 19 | weiterhin falsch |

**Keine der drei Scorekorrekturen ist durch die bisherigen Updates behoben.**
Jeder Replay zählt genau einen Treffer; die vorliegende Prüfung zeigt falsche
Scoreentscheidungen, nicht das vollständige Ausbleiben einer Entscheidung.

## Beobachtungen

- 183: Ein Zwischenbild liefert bereits eine Zweikamera-Schätzung für 20.
  Die abschließende zeitliche Auswahl zählt trotzdem 1. Die neue Regel für
  unabhängig bestätigte Drei-Kamera-Schätzungen greift bei dieser Zweikamera-
  Alternative nicht.
- 173: Die entscheidenden Zweikamera-Schnittpunkte liegen weiterhin im
  20-Segment. Es handelt sich nicht um die zuletzt behobene Single-/Triple-
  Verwechslung bei Fall 42.
- 92: Auch der Schnitt aller drei Kameraachsen liegt im 19-Segment
  (Residuum ungefähr 0,58 mm), während die Benutzerkorrektur 3 lautet.
  Mehr übereinstimmende Kameraachsen garantieren also keinen richtigen Score.
  Aus diesem Replay allein ist die Ursache, etwa Schaft-/Kontakt- oder
  Kalibrierungsfehler, nicht abschließend bestimmt.

## Verfahren

Alle drei Original-ZIPs separat entpackt. Die acht gespeicherten Videoframes
und vier Nachframes pro Kamera wurden mit den ursprünglichen Host-Zeitstempeln
und gespeicherter Kalibrierung durch den aktuellen Controller gespielt.
Die Korrekturwerte sind ausschließlich Sollwerte der Auswertung; sie werden
nicht zur Erkennung verwendet. Keine App-Änderung, keine Neukalibrierung und
keine Änderung an den Benutzerstatistiken vorgenommen.

Der Replay-Test ist technisch erfolgreich durchgelaufen. Sein grünes Ergebnis
bestätigt die Ausführung, nicht die Richtigkeit der Scores. Die drei ausgewählten
Fehlerfälle sind keine repräsentative Messung der allgemeinen Genauigkeit.

Rohdaten: `build/autoscore_analysis/preupdate_183_173_92_results.json`.
Log: `build/autoscore_analysis/preupdate_183_173_92_replay.log`.
