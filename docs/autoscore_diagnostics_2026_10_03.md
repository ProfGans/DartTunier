# Auswertung der Diagnosen 3, 38, 51 und 91

Die vier ZIPs wurden am 3. Oktober 2026 ausgewertet. Die Bildpaare und Berichte liegen als Regressionen unter test/fixtures/autoscoring/corrections/case_3, case_38, case_51 und case_91.

| Fall | Gemeldet | Korrektur | Befund beim Wiederabspielen |
| --- | --- | --- | --- |
| 3 | 1 | 20, Punkt (16,29 / -150,64) mm | Zwei innere Achsen ergeben 1. Die dritte Achse wird erst im erweiterten Suchbereich sichtbar. Drei Ansichten ergeben jetzt 20 bei (16,42 / -155,51) mm. |
| 38 | Nicht erkannt | 20, ohne Punkt | Aktuelle Referenz enthält den Pfeil bereits. Gegen die ältere Referenz bleibt nur eine brauchbare Achse. Keine belastbare Fusion. |
| 51 | Nicht erkannt | 1, ohne Punkt | Aktuelle Referenz enthält den Pfeil bereits. Ältere Referenz liefert zwei fast parallele Achsen; die Geometrie bleibt zu schlecht konditioniert. |
| 91 | Nicht erkannt | 20, ohne Punkt | Aktuelle Referenz enthält den Pfeil bereits. Ältere Referenz liefert zwei Achsen und eine 20 bei (-5,26 / -89,36) mm. Das beweist noch keine erfolgreiche Live-Erkennung. |

## Änderung

Die Erkennung räumt jeder schon sichtbaren, noch nicht stabilen dritten Achse höchstens zwei zusätzliche Abgleichzyklen ein. Der bisherige Abgleich war auf Entscheidungen nahe am Draht beschränkt; Fall 3 zeigt, dass eine falsche Zweierentscheidung auch weiter vom Draht entfernt liegt.

Eine im erweiterten Außenbereich gefundene Achse darf einen Treffer innerhalb der Score-Fläche nur ergänzen, wenn zwei unabhängige innere Achsen vorhanden sind und die gemeinsame Geometrieprüfung besteht. Eine Zweierkombination mit einer solchen Außenachse autorisiert dort weiterhin keinen Score. Solche Dreierentscheidungen bleiben als unsicher markiert. Die Diagnose enthält outerRimOnly je Achse zur Nachvollziehbarkeit.

Im Fall 3 beträgt der Abstand zur manuell gesetzten Referenzposition rund 4,87 mm. Es wird kein kamerabezogener konstanter Korrekturversatz aus nur einem Beispiel gelernt. Bestehende Aufzeichnungen, insbesondere der zuvor problematische Fall 40, bleiben abgesichert.

## Offene Grenzen

Bei 38, 51 und 91 ist die aktuelle belegte Referenz bereits weitgehend identisch mit dem gemeldeten Bild. Aus der ZIP allein lässt sich nicht entscheiden, ob zuvor ein automatisch als Nicht erkannt gezählter Wurf vorlag oder eine andere Zählentscheidung die Referenz fortgeschrieben hat. Ein Rückgriff auf die ältere Referenz ist deshalb Analysehilfe, keine automatische erneute Wurfzählung: Er könnte einen schon erfassten Pfeil doppelt zählen.

38 und 51 bleiben ungelöst. Präzise gesetzte Punkte würden die Zuordnung zum richtigen Pfeil verbessern. Auch Aufnahmen direkt beim ursprünglichen Erkennungsereignis helfen. 91 ist gegen die ältere Referenz rekonstruierbar; eine Live-Behebung wird daraus nicht abgeleitet. Die gespeicherten Frames decken keine vollständige zeitliche Kamerasequenz ab.
