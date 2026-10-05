# Gedrehtes Board: Diagnose und Fix vom 2026-10-05

Eingang: `autoscore_korrektur_1.zip`, aufgenommen 2026-10-05 07:23:59 UTC.
Gemeldet: T14, korrigiert: T20. Der alte Achsenschnitt lag bei
(-100.13, -33.46) mm, obwohl der Eintritt in allen drei Bildern im T20-Feld liegt.

Zwei zusammenwirkende Ursachen wurden behoben:

- `WindowsAutomaticCalibrationService.calibrate` prüfte zuerst historische
  Ringbilder und konnte eine falsche Sektorausrichtung übernehmen, ohne die
  aktuellen Zahlen zu lesen. Jede Kalibrierung liest jetzt die aktuellen Zahlen.
  Historische Ringreferenzen werden dabei nicht mehr als Ausrichtungsquelle
  verwendet. Der Controller kann fehlgeschlagene Ansichten weiterhin mit einer
  im selben Kalibrierungslauf frisch erkannten Kamera abgleichen.
- Die permissive Farbauswahl lieferte in Kamera 1 eine scheinbar gültige, aber
  durch den orangefarbenen Surround verzerrte Ellipse. Das entzerrte Bild schnitt
  fast alle Zahlen ab. Die selektive Ringfarberkennung wird jetzt zuerst geprüft;
  für blasse Ringe bleibt die permissive Erkennung als Rückfall erhalten.

Keine Speicherformatänderung. Vorhandene Referenzen können gespeichert bleiben;
  sie überspringen die frische Zahlenerkennung nicht mehr.

Validierung:

- Echte native Windows-OCR auf allen drei beigefügten Bildern: erfolgreich.
  Kamera 2 liest drei Zahlen; Kamera 1 und 3 werden über ihren gedruckten
  Zahlenring mit der frisch kalibrierten Kamera 2 abgeglichen.
- Die drei originalen Vorher-/Trefferbilder werden mit diesen Kalibrierungen
  erneut ausgewertet. Der resultierende Score ist T20 statt T14.
- 124 Kalibrierungs-/Autoscorer-Regressionen bestanden, zusätzlich der neue
  konkrete T20-Replaytest. Die beiden gedrehten-Board-Tests bestanden zusammen.
- Analyse der fünf geänderten Dart-Dateien ohne Befunde.
- Ein erster breiter Testlauf scheiterte an einem Flutter-Kopierkonflikt bei
  sqlite3.dll; der vollständige Wiederholungslauf bestand.

Fixtures und native OCR-Kalibrierungen:
`test/fixtures/autoscoring/rotated_board/`.
Test: `test/autoscore_rotated_board_test.dart`.
Logs: `build/autoscore_analysis/rotated_board_2026_10_05/`.

Nach dem Drehen das Board leeren und neu automatisch kalibrieren bzw. Kameras
neu verbinden. Eine Drehung mitten in einer laufenden Aufnahme wird damit nicht
als Hintergrundüberwachung erkannt. Der Bild-Replay wurde tatsächlich geprüft;
Live-Aufnahme mit den angeschlossenen Kameras wurde nicht durchgeführt.
