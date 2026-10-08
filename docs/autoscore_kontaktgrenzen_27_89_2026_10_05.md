# Kontakt- und Grenzprüfung für Fälle 27 und 89

## Verhalten

Die zeitliche Auswahl behält eine frühere Position aus mindestens zwei
Kameraperspektiven, wenn nach Verlust anderer Perspektiven eine sichtbare
Spitze diese frühere Position innerhalb von 4 mm bestätigt. Die spätere
Ein-Kamera-Schätzung darf höchstens 15 mm entfernt liegen. Der Residualfehler
des früheren Kandidaten ist auf 3 mm begrenzt. Die Auswahl erfolgt spätestens
beim dritten Entscheidungskandidaten, mit gespeichertem Index und Grund
`retainedMultiviewContact`. Ohne sichtbare Bestätigung bleibt die bisherige
Auswahl aktiv. Dies behebt im Replay Fall 89: T20 statt 20.

`local_segment_boundary.dart` ergänzt eine separate lokale Segmentprüfung.
Sie verarbeitet nur nahe Segmentgrenzen, fern von Ringgrenzen, und nur einen
eindeutigen Spitzenkandidaten mit Konfidenz mindestens 0,9, der innerhalb von
4 mm liegt und eine andere Punktzahl ergeben würde. Im hochauflösenden
Leerbild wird der Schwarz-Weiß-Übergang entlang fünf naher Radien bilinear
gemessen. Mindestens vier deutliche, konsistente Übergänge sind nötig.
Ringbereiche, geringe Kontraste und mehrdeutige Übergänge werden verworfen.

Mindestens zwei Kameras müssen einen Wechsel über ihre tatsächlich gemessene
Grenze mit mindestens 0,5 mm Abstand auf beiden Seiten und mindestens sechs
neuen zusammenhängend unterstützten Pixeln in einer 2,5-mm-Kontaktumgebung
bestätigen. Die zugehörige Schaftachse darf höchstens 3 mm entfernt sein.
Es wird kein pauschaler Positionsversatz gelernt. Dies behebt im Replay
Fall 27: 3 statt 19. Die Spitze stammt weiter aus dem aktuellen Wurfbild;
das Leerbild liefert nur die lokale Grenze.

Die Diagnose enthält Messwerte, unterstützende Kameras, Kandidaten und Gründe
unter `localSegmentBoundary`, zusätzlich einen separaten Laufzeitschritt.
Die Algorithmusrevision ist `contact-boundary-v1-2026-10-05`.
Das additive Berichtsschema bleibt Version 8.

## Validierung und Grenzen

- Beide neuen realen Sequenzen sind als feste Produktions-Replay-Tests
  hinterlegt. Sollpunkte sind kein Erkennungsinput.
- Tests prüfen auch fehlende Kontaktpixel, nur eine unterstützende Kamera,
  geringen Kontrast, fehlende Detailbilder und nicht bestätigte oder entfernte
  zeitliche Kandidaten.
- Alle 25 alten Diagnosepakete liefern unveränderte Ergebnisse gegenüber
  `contact_tracking_old25.json`, einschließlich der bekannten Fehler.
- Die Stapel `batch_2026_10_05`, `batch2`, `batch3`, `batch4` mit 13, 6, 4
  und 3 Paketen bleiben ebenfalls unverändert gegenüber den `recovery_*`-
  Ergebnissen. Die Pakete können sich mit den 25 überschneiden.
- Die Sequenzen 5, 97, 126, 42, 20 und 183 bleiben korrekt. Die bekannten
  Fehler 173 (20 statt 5) und 92 (19 statt 3) bestehen weiter.
- Lokale Grenzprüfung im instrumentierten Replay: Fall 27 maximal 2,39 ms,
  durchschnittlich 1,27 ms pro ausgeführtem Grenzprüfschritt; Fall 89 maximal
  0,08 ms. Dies ist eine lokale Messung, kein garantierter Live-Latenzwert.

Keine Live-USB-Würfe wurden durchgeführt. Die offline Diagnosen sind eine
gezielte Fehlerauswahl und belegen keine Gesamtgenauigkeit von 99,5 Prozent.
Ergebnisse und Logs liegen unter `build/autoscore_analysis/contact_boundary_*`.
256 relevante Tests bestanden; Windows-Release-Build erfolgreich.
Die statische Analyse meldet ausschließlich den vorhandenen Lint-Hinweis in
`test/manual_update_card_test.dart:35`.
