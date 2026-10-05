# Erweiterte Autoscore-Diagnose (Schema 8)

Mit „Allgemeine Diagnose erstellen“ im Autoscorer oder Kamera-Bereich des
Spiels lässt sich jederzeit ein unabhängiger Bericht sichern. Der Zustand wird
beim Anklicken aufgenommen, bevor die optionale Fehlerbeschreibung eingegeben
wird. Danach öffnet sich die Dateiauswahl für den ZIP-Export. Bei Abbruch der
Dateiauswahl bleibt die bereits gespeicherte Datei im Diagnoseordner erhalten.
Auch ohne erkannte Treffer, vollständige Kamerabilder oder Kalibrierung ist
dies möglich. Der Export löst keine Korrektur und keinen Reset aus.

Neue Diagnose-ZIPs enthalten zusätzlich `DIAGNOSE_UEBERSICHT.txt` und
`diagnose_zusammenfassung.json`. Bestehende Bilder und Berichtsfelder bleiben
erhalten. Das additive Berichtsschema hat Version 8; ältere Diagnosepakete
können weiterhin mit den bisherigen Replay-Werkzeugen geprüft werden.

Die Ergänzungen umfassen:

- App-Version, Build, Betriebssystem und Diagnose-Revision.
- Kameraidentität, Kalibrierungsstatus und Wiederverwendung der Kalibrierung.
- Zeitliche Auswahlgründe und Gründe für Annahme oder Ablehnung der
  Spitzenverfeinerung.
- Die letzten zwölf Verarbeitungsschritte mit Bewegungs-, Achsen-,
  Mehrkamera-, Herauszieh- und Entscheidungszuständen sowie Laufzeiten.
- Aufnahmeabstände, wiederholte oder rückläufige Zeitstempel und
  Sequenzlücken der gespeicherten Kamerabilder.
- Helligkeit, dunkle/helle Sättigung und Laplace-Varianz als Bildqualitätsindiz.
- Letzten Aufnahmefehler inklusive Stacktrace, sofern vorhanden.

Wenn der ausgewählte Entscheidungsframe in der gespeicherten Sequenz liegt,
wird er als `kamera_N_entscheidung.png` exportiert, bei vorhandenen Daten
zusätzlich in Farbe und Detailauflösung. Die Kontaktprüfung verwendet dieses
Bild. Andernfalls kennzeichnet `imageSource` ausdrücklich den Rückgriff auf
das zuletzt gespeicherte Trefferbild. Fehlende Daten bleiben als solche sichtbar.

Zeitstempel messen den Empfang am Rechner, keine hardwareseitige
Kamerasynchronisation. Sequenzlücken bedeuten nicht zwingend verlorene USB-Bilder.
Bildqualitätswerte gelten für das ganze Graubild und sind kein nachgewiesener
Fokus- oder Kalibrierungsfehler. Die Laufzeiten umfassen die Verarbeitung,
nicht Aufnahme und Dekodierung; ein im Treffer-Callback erstellter Bericht
enthält nur die bis dahin abgeschlossenen Schritte.

Die Metadaten ändern keine Trefferentscheidung. Die App-Version wird ohne
Warten im Kamerastart geladen; falls sie noch nicht vorliegt, fehlt sie im
frühen Bericht. Es ist keine erneute Kalibrierung für das neue Schema nötig.
