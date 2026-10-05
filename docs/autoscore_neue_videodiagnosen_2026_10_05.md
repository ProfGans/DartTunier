# Neue Videodiagnosen: 5, 97 und 126

Die neuen ZIPs enthalten echte Vorher-Sequenzen, Zeitstempel und bis zu vier
Nachherbilder. Der chronologische Replay verwendet die originalen Grau- und
Detailpixel, Kalibrierungen und Zeitstempel. Die Benutzerkorrekturen werden nur
zur abschließenden Bewertung gelesen, nicht zur Erkennungsentscheidung.

| Fall | Gespeichert / Replay vor Änderung | Korrektur | Replay nach Änderung |
| --- | --- | --- | --- |
| 5 | 1 | T1 | T1 |
| 97 | 1 | 20 | 20 |
| 126 | MISS | T20 | MISS, weiterhin offen |

## Behobene Ursachen

Bei Fall 5 ergibt die gemeinsame Schaftschätzung tatsächlich T1. Zwei scheinbare
Schaftenden verschieben den Punkt jedoch über die Ringgrenze und überschreiben
die Dreikamera-Entscheidung. Zwei Endpunkte dürfen jetzt einen konsistenten
Dreikamera-Score nicht ändern; dafür wird die dritte Ansicht benötigt. Die
Spitzensuche bleibt für andere bestätigte Verfeinerungen verfügbar.

Bei Fall 97 liegt der Fehler der Kamera-2-Achse relativ zur gemeinsamen Schätzung
im Zentimeterbereich. Die Linie stammt aus einer reinen Randbeobachtung; die
beiden anderen starken Schaftachsen schneiden sich im 20er-Feld. Nur für diesen
physikalisch eingeschränkten Fall wird die Randachse verworfen: zwei normale
Achsen mit Qualität mindestens 0,85, ihr Schnitt innerhalb von 160 mm, dritte
Achse als reine Randbeobachtung, Abstand zum Schnitt größer als 20 mm und
zuvor keine plausible Dreikamera-Fusion. Das Ergebnis bleibt eine markierte
Zweikamera-Schätzung. Allgemeine Widersprüche zwischen drei normalen Kamera-
Beobachtungen werden dadurch nicht beliebig zugunsten eines Paars aufgelöst.

## Offener enger Wurf

Bei Fall 126 verfolgt die primäre Kamera-1-Achse eine Änderung am Zahlenring,
während der neue Kontaktbereich durch vorhandene Darts verdeckt ist. Unter
alternativen Linien gibt es Schnittpunkte im T20-Feld. Diese werden aber nicht
durch zwei sichtbare Endpunkte bestätigt. In Kamera 1 liegt die nächste deutliche
Änderung ungefähr 79 mm vom alternativen Kontaktpunkt entfernt; in Kamera 3
ungefähr 12 mm. Eine automatische Auswahl allein wegen des bekannten Zielwerts
wäre eine Anpassung auf das Diagnosepaket. Der Fehlwurf ist weiterhin offen.

## Geschwindigkeit

Die RANSAC-Liniensuche berechnet die unveränderliche Länge einer Hypothese einmal
und erzeugt eine Inlier-Liste nur für eine bessere Hypothese. Zufallsfolge,
Auswahlregeln und Ergebnis bleiben erhalten. Im gepaarten Benchmark mit acht
verschiedenen verrauschten Punktmengen stimmen Achsen und Qualität exakt mit
der bisherigen Implementierung überein. Drei Durchläufe benötigen vorher
110,83 / 110,16 / 114,77 ms und danach 69,55 / 67,50 / 69,52 ms: ungefähr
37 bis 39 Prozent weniger Zeit für diese Linienberechnung. Das ist keine
Messung der gesamten USB-Latenz oder der Erkennung am angeschlossenen Board.

Die gelieferten Berichte messen etwa 57–83 ms für Aufnahme/Dekodierung und
202–217 ms für Bildverarbeitung in den drei Fehlerereignissen. Die Zahl verworfener
nativer Bilder ist ein kumulativer Zähler seit Verbindung, keine Fehlerquote.

## Prüfstatistik und Grenzen

Die exportierte Serie umfasst 129 erfasste Ereignisse. Drei wurden ausdrücklich
als falsch überprüft; die übrigen 126 sind nicht unabhängig bestätigt. Deshalb
sind die angezeigten 0 Prozent nur das Ergebnis der drei expliziten Prüfungen.
129 minus drei wäre unter der Annahme sonst fehlerfreier und vollständig erkannter
Würfe ungefähr 97,7 Prozent; diese Annahme ist durch den Export nicht belegt.
Die alten insgesamt 698 ungeprüften Setup-Ereignisse sind nicht gleich dieser Serie.

Zwei von drei ausgewählten Korrekturen sind im Replay behoben. Daraus folgt keine
allgemeine Genauigkeitsquote und weiterhin kein Nachweis für 99,5 Prozent.
Die Kameraeinrichtung wurde anhand gespeicherter Sequenzen geprüft, nicht durch
einen neuen physischen USB-Test. Automatisches Herausziehen bestätigt weiterhin
die Alltagsstatistik; die unabhängige Prüfserie verlangt ausdrückliche Prüfung.

## Reproduzierbarkeit

- Chronologischer Replay: `tool/autoscore_new_video_replay_test.dart`.
- Dauerhafte echte Bildregressionen: `test/autoscore_new_video_corrections_test.dart`.
- Vergleich der Liniensuche: `tool/autoscore_line_fit_benchmark_test.dart`; die
  vorherige Implementierung unter `tool/support/` dient nur als Test-/Benchmark-
  Referenz und wird von der App nicht importiert.
- Rohdaten/Logs: `build/autoscore_analysis/new_video_baseline.json`,
  `new_video_without_tips.json`, `new_video_improved.json`,
  `line_fit_timings.json` und `new_video_regressions.log`.

238 bisherige Autoscorer-Regressionen bestanden nach den App-Änderungen.
Die drei neuen gezielten Bild-/Ausreißerregressionen und der Benchmark mit
Ergebnisgleichheit bestanden ebenfalls. Kalibrierung, Statistikpersistenz und
Oberflächen wurden durch diese Änderung nicht verändert.
