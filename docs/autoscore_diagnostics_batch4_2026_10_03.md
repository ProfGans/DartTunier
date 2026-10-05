# Diagnose-Serie 143, 68 und 24

Die gespeicherten Würfe werden mit der produktiven Erkennung und der ursprünglichen Vorher-Referenz nachgespielt. Automatisch übernommene Ergebnisse stehen bereits in der aktuellen Referenz; für die Analyse wird deshalb `kamera_N_letzter_vorher.png` verwendet.

| Paket | Bisheriges Ergebnis | Auswertung |
| --- | --- | --- |
| 68 | Nicht erkannt, korrigiert auf 20 | Nur Kamera 3 hatte eine Achse. Ein zusätzlicher Fit im inneren 100-mm-Bereich gewinnt in Kamera 2 eine Achse mit Qualität 0,840. Zusammen ergeben sie eine unsichere 20 bei (8,09; -96,76) mm, etwa 5,61 mm vom gesetzten Punkt entfernt. Der Controller zählt im Replay genau einmal. |
| 143 | T5, korrigiert auf T20 | Position (-17,37; -103,47) mm statt (-9,43; -104,14) mm: etwa 7,97 mm Fehler, knapp über die Segmentgrenze. Bleibt ungelöst und prüfbedürftig. |
| 24 | 5, korrigiert auf T5 | Position (-22,37; -91,72) mm statt (-26,57; -98,14) mm: etwa 7,68 mm Fehler. Bleibt ungelöst und prüfbedürftig. |

Der neue Rückfall wird nur verwendet, wenn der bisherige 190-mm-Fit keine Achse findet. Er benötigt mindestens 0,8 Linienqualität. Anschließend bleiben dieselben geometrischen Prüfungen und die begrenzte Entscheidungsphase wirksam. Erfolgreiche vorhandene Fits werden nicht ersetzt. Der äußere 230-mm-Fit bleibt verfügbar.

Versuche mit generell kleineren Fit-Bereichen und einem lokalen Fit um die geschätzte Spitze verbesserten einzelne Beispiele, verschlechterten aber andere. Sie wurden nicht übernommen. Insbesondere ließ sich aus diesen drei Aufnahmen keine allgemeine, zuverlässige Korrektur für Triple- und Segmentgrenzen ableiten. Die zwei offenen Fälle sind bewusst als bekannte Einschränkungen im Regressionstest dokumentiert.

82 Erkennungs-, Controller-, Diagnose- und Resetprüfungen bestanden. Die Wiedergabe statischer Diagnosebilder ersetzt keine Liveprüfung an den USB-Kameras.
