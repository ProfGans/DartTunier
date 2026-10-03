# Auswertung: Herausziehen und Korrekturen 1, 8, 61, 73, 76

## Trefferkorrekturen

Alle fünf Diagnosen enthalten einen manuell gesetzten Einschlagpunkt. Zwei klar ausgeprägte Kameraachsen sind vorhanden; Kamera 2 liefert keine verwertbare Achse. Eine der beiden guten Achsen wird erst bei Einbezug des erweiterten Außenbereichs erkennbar. Die bisherige Regel verlangte für innere Treffer zwei ausschließlich im engeren Bereich ermittelte Achsen und wies diese Kombination deshalb vollständig ab.

Die neue Regel erlaubt eine solche Zweierkombination, wenn beide Achsen eine Linienqualität von mindestens 0,85 besitzen, mindestens eine im inneren Bereich gewonnen wurde und die bestehenden Prüfungen von Winkel, Lage und Geometrie bestehen. 0,85 ist eine interne Linienqualität, keine gemessene Trefferwahrscheinlichkeit. Das Ergebnis bleibt unsicher markiert.

| Korrektur | Referenz | Neues Ergebnis im Replay | Abstand zum gesetzten Punkt |
| --- | --- | --- | --- |
| 1 | 20 | 20 | 1,37 mm |
| 8 | 20 | 20 | 7,89 mm |
| 61 | 20 | 20 | 1,33 mm |
| 73 | 20 | 20 | 1,36 mm |
| 76 | 20 | 20 | 2,44 mm |

Fall 8 hat weiterhin eine deutlich größere Positionsabweichung, obwohl der Score stimmt. Die Tests prüfen den tatsächlichen Controller-Ablauf einschließlich einmaliger Übernahme und unveränderter Folgebilder. Fall 40 aus einer älteren Serie liefert unter dieser Regel ebenfalls einen unsicheren Zweikamera-Treffer; mangels bestätigtem Score/Punkt gilt er weiterhin nicht als nachgewiesene Genauigkeitsverbesserung.

## Herausziehen

Die Fotos zeigen ein leeres Board. Die alte Prüfung bleibt dennoch hängen:

| Kamera | Vorherige Differenzpixel im Boardbereich | Aktuelle Restpixel | Davon an vorher belegten Pixeln |
| --- | --- | --- | --- |
| 1 | 1051 | 256 | 242 |
| 2 | 1766 | 25 | 6 |
| 3 | 379 | 19 | 7 |

Zwei Ansichten sind bereits eindeutig leer. In Kamera 1 verbleiben wenige Bildreste, die gegenüber der alten Leerreferenz differieren; es wird kein Schaft gefunden. Die genaue physikalische Ursache (z. B. Reflexion, Schatten oder Fokus) lässt sich aus den Einzelbildern nicht sicher bestimmen.

Die neue Wiederherstellung greift nur bei zwei unabhängig leer geprüften Kameras. In der dritten müssen mehr als 70 Prozent der vorherigen Differenzen verschwunden sein, die verbleibende Differenz höchstens 0,5 Prozent der geprüften Boardpixel ausmachen, neu hinzugekommene Änderungen sehr klein sein und die Schaftprüfung gegen die Leerreferenz erfolglos bleiben. Dafür werden sechs ruhige Beobachtungen verlangt. Bei vollständiger Belegung einer dritten Kamera bleibt der Reset gesperrt. Die normale Leerprüfung bleibt bei drei ruhigen Beobachtungen.

Die gespeicherte Herauszieh-Sequenz wird jetzt zurückgesetzt. Im Controller-Test bleiben Zählung und pending leer, der Wartezustand endet und die Erkennung läuft weiter. Künftige manuelle Herauszieh-Diagnosen enthalten removalMetrics mit Restpixelzahlen und Prüfstatus je Kamera.

## Prüfung und Grenzen

Die sechs Archive liegen als dauerhafte Regressionen unter test/fixtures/autoscoring/batch2. Zusätzlich werden frühere Korrekturen, fehlende/parallel liegende Achsen, verbleibende Pfeile und Herausziehen nach einem bzw. zwei Würfen geprüft. Die Ergebnisse sind Replay-Ergebnisse aus einzelnen gespeicherten Bildern; eine vollständige zeitliche Sequenz und ein neuer Live-Test liegen nicht vor. Daraus folgt keine allgemeine Genauigkeitsquote.
