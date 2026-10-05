# Blockade nach dem ersten Dart: Wiederherstellung des belegten Boards

05.10.2026

## Reproduzierte Ursache

Die Herauszieh-Erkennung verriegelte sich, sobald zwei Kameras das Verschwinden
alter Dartpixel meldeten. Kehrte die vollständig belegte Referenz nach einer
kurzen Verdeckung oder Bewegung zurück, blieb `waitingForEmpty` trotzdem aktiv.
Der produktive Controller übersprang dann die nächste Trefferentscheidung.
Das ist eine nachgestellte mögliche Ursache; ohne aktuelle Live-Diagnose ist
nicht bewiesen, dass dies jeden vom Benutzer beobachteten Stillstand erklärt.

## Änderung

Eine vorzeitig verriegelte, noch unvollständige Aufnahme wird freigegeben, wenn
alle drei Ansichten das vollständige belegte Referenzbild wieder zeigen:
keine aktuelle Entfernung, ruhiges Board und drei aufeinanderfolgende passende
Captures. Entfernte und hinzugefügte Pixel dürfen jeweils höchstens drei Prozent
der vorherigen Dartpixel ausmachen (mindestens zwei Pixel Rauschtoleranz).

Bei erreichtem Dartlimit bleibt die Herauszieh-Sperre aktiv. Tatsächlich teilweise
entfernte Darts erfüllen den Referenzvergleich nicht. Scores und Bildreferenzen
werden beim Entsperren nicht gelöscht. Diagnosewerte enthalten pro Kamera
`occupiedRestored`.

## Prüfungen

- Controller-Test: erster Dart zählt, kurzfristiger Entfernungsverdacht verriegelt,
  Wiederherstellung entsperrt ohne Doppelzählung; zweiter Dart zählt anschließend.
- Domain-Tests: Wiederherstellung nach einem und zwei Darts entsperrt; nach drei
  Darts bleibt die Aufnahme abgeschlossen; echte Teilentfernung bleibt gesperrt.
- Gesamte Autoscoring-Suite: 247 Tests bestanden.
- Gespeicherte Videofälle 5, 97, 126 bleiben T1, 20, T20.
- Flutter-Analyse und Windows-Build geprüft; bestehender Style-Hinweis in
  `test/manual_update_card_test.dart:35`.

Kein neuer Live-Wurf mit den angeschlossenen USB-Kameras durchgeführt.
