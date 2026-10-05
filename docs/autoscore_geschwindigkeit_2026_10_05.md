# Weitere Geschwindigkeitsprüfung (2026-10-05)

## Umsetzung

Die Erkennungsschwellen und Entscheidungsfristen bleiben unverändert.

- Board-Abstände werden einmal pro geändertem Pixel berechnet und für die
  verschiedenen Radius-Prüfungen wiederverwendet.
- Nachbarschaftsprüfungen enden, sobald die erforderlichen drei Pixel gefunden
  wurden. Das bisherige boolesche Ergebnis bleibt identisch.
- Bereits entzerrte Bildpunkte werden direkt projiziert. Die iterative
  Linsenkorrektur wird in der Detailprüfung nicht mehr doppelt ausgeführt.
- Die Länge einer unveränderten Schaftrichtung wird vor der Pixelschleife
  berechnet.

## Messung

Gepaarter CPU-Vergleich gegen den gesicherten Detector vor dieser Änderung.
75 Kamerabilder aus den 25 alten Diagnosepaketen und neun Detailbilder aus
5, 97 und 126. Beide Varianten verwenden die bestehende Wiederverwendung der
Bildänderungen innerhalb eines frischen Frames. Bildladen und PNG-Decodieren
liegen außerhalb der Messung. Nach Aufwärmen wechseln sich die Reihenfolgen ab.

| Lauf | Vorher, ms für 84 Kamerabilder | Jetzt, ms | Einsparung |
| --- | --- | --- | --- |
| 1 | 193,278 | 180,723 | 6,50 % |
| 2 | 197,514 | 183,240 | 7,23 % |
| 3 | 191,425 | 173,584 | 9,32 % |
| 4 | 198,674 | 182,106 | 8,34 % |
| 5 | 194,340 | 178,885 | 7,95 % |

Median der gepaarten Einsparungen: rund 8 Prozent in der Achsen-/Kandidatenprüfung.
Keine Messung der gesamten Live-Latenz, USB-Aufnahme oder Ansage. Ein früherer
kleinerer Versuch ohne die Detailoptimierungen schwankte zwischen Verschlechterung
und Verbesserung; daraus wurde kein belastbarer Geschwindigkeitsgewinn abgeleitet.

## Absicherung

- Alle Achsenkoeffizienten, Konfidenzen, Außenrand-Markierungen und Anzahl der
  Kandidaten aus 84 Kamerabildern stimmen exakt mit der bisherigen Variante überein.
- 242 Autoscoring-Tests bestanden.
- Die 25 zuletzt geprüften alten Pakete behalten alle ihre Scores.
- Die tatsächlichen gespeicherten Videosequenzen 5, 97 und 126 liefern weiterhin
  T1, 20 und T20.
- Windows-Build geprüft. Analyse enthält nur den vorhandenen Style-Hinweis in
  `test/manual_update_card_test.dart:35`.

Reproduzierbarer Vergleich: `flutter test tool/autoscore_detector_speed_test.dart`.
Benötigt die entpackten Diagnosen in `build/autoscore_analysis/user_old_25` und
`build/autoscore_analysis/new_2026_10_05`. Rohmessung:
`build/autoscore_analysis/detector_speed_timings.json`.

Für einen größeren Gewinn muss als Nächstes die vollständige Live-Pipeline separat
vermessen werden, insbesondere Bildaufbereitung, Farb-JPEGs für Diagnosen und
Detail-/Spitzenanalyse. Diese Offline-Messung rechtfertigt keine Aussage über
zusätzliche FPS oder eine bestimmte Zeit vom Einschlag bis zur Ansage.
