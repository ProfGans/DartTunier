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
