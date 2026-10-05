# Prüfung der 25 alten Autoscore-Diagnosen

Geprüft am 05.10.2026 mit der aktuellen produktiven Erkennung. Keine Änderung an der App oder deinen Genauigkeitsstatistiken.

**Ergebnis: 13 richtig, 8 falscher Score, 2 ohne Erkennung, 2 ohne eindeutigen Sollwert.** Das entspricht 13 von 23 bewertbaren Problemfällen (56,5 %). Diese gezielt ausgewählten früheren Fehlerfälle ergeben keine allgemeine Live-Genauigkeit.

| Paket | Damals | Sollwert | Jetzt | Ergebnis |
| --- | --- | --- | --- | --- |
| 1 | Nicht erkannt | 20 | 20 | richtig |
| 25 | 7 | T7 | 7 | falsch |
| 26 | Nicht erkannt | D20 | D20 | richtig |
| 3 | 1 | 20 | 20 | richtig |
| 32 | Nicht erkannt | Nicht erkannt | 20 | nicht bewertbar |
| 32 (2) | Nicht erkannt | 20 | 20 | richtig |
| 38 | Nicht erkannt | 20 | 20 | richtig |
| 39 | 3 | 19 | 3 | falsch |
| 40 | Nicht erkannt | Nicht erkannt | 20 | nicht bewertbar |
| 43 | Nicht erkannt | 20 | kein Treffer | nicht erkannt |
| 46 | 7 | 19 | 19 | richtig |
| 51 | Nicht erkannt | 1 | 1 | richtig |
| 54 | 13 | T13 | 13 | falsch |
| 56 | 20 | 1 | 20 | falsch |
| 59 | Nicht erkannt | 3 | kein Treffer | nicht erkannt |
| 6 | Nicht erkannt | D5 | D5 | richtig |
| 61 | Nicht erkannt | 20 | 20 | richtig |
| 62 | 20 | 1 | 20 | falsch |
| 67 | T20 | T1 | T20 | falsch |
| 73 | Nicht erkannt | 20 | 20 | richtig |
| 76 | Nicht erkannt | 20 | 20 | richtig |
| 77 | 20 | 1 | 20 | falsch |
| 8 | Nicht erkannt | 20 | 20 | richtig |
| 9 | Nicht erkannt | 20 | 18 | falsch |
| 91 | Nicht erkannt | 20 | 20 | richtig |

## Verfahren und Grenzen

- Alle 25 gelieferten ZIPs separat entpackt und deren eigene Kalibrierung verwendet. Keine Sollwerte in die Erkennung eingespeist.
- Produktiven Controller mit aktivem Video-Erkennungspfad auf den gespeicherten Vorher-/Trefferbildern achtmal ausgeführt, um seine begrenzte Entscheidungslogik abzuspielen.
- Diese Pakete haben Schema 1 bis 3 und keine fortlaufenden Frame-Zeitstempel. Die zeitliche Zusatzprüfung für Fall 126 wird deshalb nicht aktiviert. Wiederholte identische Bilder sind kein neues Kameravideo.
- Fall 32 und 32 (2) sind unterschiedliche Aufnahmen, nicht dasselbe Ereignis. Alle 25 Berichte haben unterschiedliche Hashes und Capture-Zeitpunkte.
- 32 und 40 ergeben heute einen geschätzten Score 20. Da im Bericht weiterhin „Nicht erkannt“ als Korrektur steht, lässt sich deren Richtigkeit nicht bestätigen.
- Der Replay-Test bestand: Das bestätigt den erfolgreichen Durchlauf, nicht 25 korrekte Scores.
- Keine neuen Live-Würfe und keine Neukalibrierung der alten Bilder durchgeführt.

Besonders offen bleiben die Single/Triple-Verwechslungen 25 und 54, die Segmentverwechslungen 39, 56, 62, 67, 77 und 9 sowie fehlende Erkennungen 43 und 59.

Rohdaten: `build/autoscore_analysis/user_old_25_results.json`; Ausführung: `build/autoscore_analysis/user_old_25_replay.log`.
