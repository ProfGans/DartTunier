# Real video correction fixtures, 2026-10-05

Sources: autoscore_korrektur_5.zip and autoscore_korrektur_97.zip supplied by
the user. Preserve the original calibration and full-resolution grayscale
reference, empty-board and seventh sequence frame from all three cameras.
Reports retain the recorded decision and manually corrected label/point.

The regression feeds recorded pixels to the production controller with the
video endpoint branch enabled. Correction labels/points are evaluation-only.
Repeated still frames test decision stability and duplicate suppression; they
do not simulate capture timing. Full chronological 8-before/4-after replays
from the original archives are performed by tool/autoscore_new_video_replay_test.dart.

Case 5: two endpoint estimates used to overwrite the correct three-camera T1
result with single 1. Case 97: a contradictory rim-only camera observation
pulled two strong inner-board shaft observations from 20 into 1.

Fall 126: originale Vorher-/Leerbilder und zwei zeitlich getrennte Sequenzframes samt Detailbildern. Regression für verdeckte Schäfte und unabhängige dritte Kamera; Sollwert wird nicht in die Erkennung eingespeist.

Fälle 42 und 20: komplette acht Frames mit Host-Zeitstempeln; Schutz vor falschem Spitzenscore und Vorrang konsistenter Drei-Kamera-Schätzungen am Deadline-Schritt.

Fall 183: volle Originalsequenz; widersprüchliche Kameraachsen, bestätigte Schaftalternative mit neuer dritter Kamera-Pixelstützung und zeitliche Endauswahl.

Fälle 6, 56, 99 und 111 vom 06.10.2026: acht Originalframes mit Zeitstempeln,
Leer-/Vorherbilder und unveränderte Kalibrierung. 6/99 schützen sichtbare
Spitzenendpunkte bei Ein-Kamera-Schätzungen. 56 schützt die Triple-Entscheidung
mit unabhängigen Endpunkten, lokalen Änderungen und gemessenen Ringkanten;
die originalen Farbleerbilder sind dafür enthalten. 111 schützt die zeitliche
Beibehaltung eines gemessenen Segmentkontakts. Sollwerte werden ausschließlich
in den Erwartungen benutzt, nicht zur Erzeugung von Kandidaten.

`case_ordner9_2`, `case_ordner9_56` und `case_ordner9_68`: neue Aufnahmen mit
denselben numerischen IDs aus Neuer Ordner (9), bewusst getrennt von früheren
Fällen. Vollständige acht Originalframes sichern T5, T20 und den vom Nutzer
bestätigten Bouncer mit null Punkten. Zeitstempel und Kalibrierung bleiben
unverändert. Die Bouncer-Erwartung stammt aus der Nutzeraussage; ein manuell
verschobener Boardpunkt ist für diesen Fall kein Kontakt-Trainingslabel.
`case_102` und `case_134`: Originaldiagnosen aus Neuer Ordner (4), acht
Bildpakete samt Detailbildern, Farbleerbildern, Kalibrierung und Zeitstempeln.
Erwartungen sind T1 beziehungsweise 3. Sie sichern den lokal gemessenen
Endpunkt an Ring-/Segmentgrenzen und seine zeitliche Beibehaltung. Die
Korrekturposition wird der Erkennung nicht übergeben.

