# Präzisionspipeline des Autoscorers

Stand: 3. Oktober 2026. Die Pipeline verarbeitet weiterhin echte Aufnahmen von drei USB-Kameras. Sie verwendet keine simulierten Treffer und kein trainiertes Dartmodell.

## Kalibrierung

Die bisherige automatische Bull-, Ring- und Zahlenerkennung bleibt der Ausgangspunkt. Die vorhandene Feinrotation wertet die zwanzig Segmentgrenzen aus. Anschließend sucht `dense_board_calibration.dart` bis zu vierzig zusätzliche Farbring-Mittelpunkte: zwanzig am Triple-Ring und zwanzig am Double-Ring.

Mindestens 28 Punkte aus mindestens 16 Segmenten sind nötig. Gerade und ungerade Segmente werden als Trainings- und Prüfmenge getrennt. Ein überbestimmter projektiver Fit mit einer begrenzten radialen Objektivkorrektur darf nur übernommen werden, wenn die unabhängige RMS-Abweichung mindestens 0,25 mm und 20 Prozent sinkt. Eine Verschiebung von mehr als 6 mm an kontrollierten Positionen bis in den Außenbereich verwirft den Fit. Fehlende oder unzuverlässige Ringpunkte lassen die bestehende Kalibrierung unverändert.

`lens_distortion.dart` verwendet einen radialen Koeffizienten und einen festen optischen Mittelpunkt. Dies ist eine begrenzte Bildkorrektur, keine vollständige intrinsische Kamerakalibrierung mit Kalibriertafel. Tangentiale Verzerrung, beliebige optische Mittelpunkte und alle Objektive lassen sich damit nicht sicher bestimmen. Koeffizienten sind abhängig vom Bildformat begrenzt. Projektion, inverse Projektion, Kamera-Overlay, flache Ansicht und Diagnoseexport verwenden dasselbe Modell.

Die Kameraanzeige ergänzt die Ringprüfung um Punktzahl und Abweichung. Die Abweichung ist ein Kalibrierungsmaß, keine Trefferquote. Nach dem Update einmal auf leerem Board automatisch neu kalibrieren.

## Originalpixel und Schaftkandidaten

`GrayFrame` behält zusätzlich zur schnellen 480-Pixel-Ansicht eine Detailreferenz mit bis zu 1280 Pixeln Breite. Kleinere Kamerabilder werden nicht künstlich hochgerechnet. Motion-, Herauszieh- und Bouncer-Prüfungen bleiben auf der kleinen Ansicht.

Der erste Schaftfit findet eine Linie im kleinen Bild. Originalpixel in einem schmalen Korridor dieser Linie werden mit RANSAC und einer PCA-Ausgleichsgeraden nachgeprüft. Die Rechnung findet in entzerrten Bildkoordinaten statt und liefert auch zwischen Pixeln liegende Geraden. Bei einer vorläufigen Trefferposition wird zusätzlich nur ein Bereich von etwa 80 mm um die vermutete Spitze untersucht. Ein Detailfit darf die Position höchstens 3 mm verändern, benötigt weiter mindestens zwei Ansichten und darf die geometrischen Prüfungen nicht verletzen. Ein Segmentwechsel bleibt als unsicher markiert.

`FrameDetector.candidates` liefert höchstens vier unterscheidbare Achsen pro Kamera. Neben Fits verschiedener Boardbereiche kann nach Entfernen der dominanten Linie eine weitere zusammenhängende Linie gefunden werden. Zusätzliche Kandidaten müssen eine Mindestqualität erreichen. Sie werden nicht einzeln als Treffer gezählt.

`multi_camera_consensus.dart` vergleicht Kombinationen mit höchstens einer Achse je Kamera. Eine zweite Linie aus derselben Ansicht ersetzt keine zweite Kamera. Eine eindeutige, geometrisch konsistente Dreierkombination darf einen schwächeren Zweierfit ersetzen. Gleichwertige, weit auseinanderliegende Kombinationen führen nicht zu einer beliebigen Wahl. Alternative Lösungen sind prüfbedürftig.

## Begrenzte Entscheidung über Bildfolgen

`temporal_hit_decision.dart` wartet auf zwei übereinstimmende Positionsvorschläge. Falls Vorschläge wechseln, wird spätestens beim dritten Vorschlag eine tatsächlich beobachtete mittlere Position übernommen und als unsicher markiert. Positionen werden nicht über eine Drahtgrenze gemittelt. Auch die vorhandene Phase für geometrisch nicht lokalisierbare Würfe bleibt begrenzt.

Die ausgewählte Position und ihre zugehörigen Kameraachsen werden gemeinsam gespeichert. Neue Würfe, Herausziehen, manuelle Resets und Neustarts löschen die Entscheidungsfenster. Pro Kamera bleiben die letzten drei Bilder für die Diagnose erhalten. Windows nutzt weiterhin Snapshot-Aufnahmen; drei Bilder sind deshalb keine garantierte feste Zeitspanne. Die reale Aufnahmegeschwindigkeit der USB-Kameras muss separat geprüft werden.

## Korrektur- und Diagnoseauswertung

Neue ZIPs verwenden Schema 5. Sie behalten bisherige Bilder und Felder und ergänzen:

- `kamera_N_vorher_detail.png`, `kamera_N_leer_detail.png` und gegebenenfalls die ältere Detailreferenz;
- bis zu drei `kamera_N_sequenz_X.png` samt vorhandener Detailansicht;
- Objektivparameter, Ringprüfwerte, Achsenkandidaten, zeitliche Vorschläge und die ausgewählte Beobachtung;
- `korrektur_auswertung.json` mit Positionsfehler, signierten Achsenfehlern je Kamera und der bisherigen Sitzungsauswertung.

Nur ausdrücklich gesetzte Korrekturpunkte sind Positionsreferenzen. Ein bestätigter Score ohne Punkt liefert keine genaue Einschlagposition. Fehlende Schätzungen werden separat gezählt. PCA-Achsenrichtungen werden vor der Berechnung signierter Fehler vereinheitlicht. Es erfolgt keine automatische pauschale Bias-Korrektur und kein Modelltraining.

Vorhandene ZIPs und `bericht.json` können gemeinsam ausgewertet werden:

```powershell
dart run tool/analyse_autoscore_diagnostics.dart test/fixtures/autoscoring --output build/autoscore_analysis/correction_summary.json
```

Das Werkzeug akzeptiert auch mehrere Ordner oder einzelne ZIPs, liest Schemas 3/4/5, ignoriert Herauszieh-Ereignisse und fasst identische Aufnahmezeitpunkte zusammen. Die vorhandenen Fixtures enthalten 26 unterschiedliche Berichte und zwölf ausdrücklich gesetzte Punkte; nur fünf davon enthalten zusätzlich eine ursprüngliche Schätzung. Diese Auswahl besteht aus Korrekturfällen und ist keine allgemeine Genauigkeitsmessung. Die Streuung rechtfertigt keinen pauschalen Positionsversatz.

## Speicherung und Verifikation

Kalibrierung und Zahlenring-Referenzen werden in Schema 2 gespeichert. Schema 1 bleibt lesbar; fehlende Objektivparameter bedeuten keine Verzerrungskorrektur. Diagnosebilder aus älteren ZIPs bleiben auswertbar. Alte 480-Pixel-Referenzen erlauben jedoch keine nachträgliche echte Detailprüfung: fehlende Originalpixel werden nicht erfunden.

Neue Unit-Tests prüfen ein unabhängig erzeugtes verzerrtes Board, Migration, höhere Detailauflösung, eindeutige und mehrdeutige Kamerakombinationen, zeitliche Entscheidungen, Richtungsnormalisierung und ZIP-Inhalte. Die gespeicherten Erkennungs- und Herauszieh-Fälle bleiben Regressionen. Die offenen Fälle 143, 24, 75 und 9_2 sind nicht allein durch diesen Umbau als behoben nachgewiesen; neue Liveaufnahmen mit hochauflösenden Referenzen sind erforderlich.

Kamera-Overlays und Positionsdialog wurden bei 360×800, 800×600 und 1440×900 sowie 200 Prozent Schrift getestet. Mobile- und Desktop-Vorschauen wurden geprüft. Eine Sichtprüfung mit echter Objektivkorrektur an den USB-Kameras und eine Prüfung auf physischen Mobilgeräten stehen aus.

Die Sitzung hält zusätzliche Detailbelege komprimiert und verwendet identische Referenzen mehrfach. Die Live-Erkennung arbeitet weiterhin mit Rohpixeln. Tests prüfen verlustfreie Wiederherstellung, Freigabe der Rohdetailreferenzen in der Diagnosehistorie und den vollständigen ZIP-Export. `decisionSelectedFrame` bezeichnet den Index in `decisionFrames`; die Kamera-PNGs dokumentieren separat die letzten aufgenommenen Bilder.

Die Prüfung von App, Tests und Werkzeug war vor den parallel hinzugekommenen Statistikdateien ohne Befunde. Der vollständige Workspace meldete zuletzt Hinweise außerhalb des Autoscorers (`build/check_release_workflow.dart` sowie Statistikdateien). Die gezielte Analyse des Autoscorers und seines Analysewerkzeugs wird separat geprüft. Der allgemeine Responsive-Test hatte einmal einen Timeout beim Mitgliederprofil; die gezielte Wiederholung bestand.

## Verpflichtende automatische Entscheidung (2026-10-03)

Bei mindestens zwei Kameras mit lokalisiertem neuem Bildunterschied wird der
Entscheidungszähler gestartet, sobald mindestens eine Ansicht ruhig ist.
Kurze unruhige Bilder und fehlende Achsenschnitte löschen vorhandene Vorschläge
nicht mehr. Spätestens mit dem sechsten vollständigen Auswertungsbild dieses
Wurfhinweises wird ein Score übernommen. Das ist eine Bildanzahl, keine feste
Zeitgarantie: USB-Aufnahme und Bildverarbeitung bestimmen die tatsächliche Dauer.

Ist kein normaler Schnitt bestimmbar, versucht `forced_hit_decision.dart` den
relaxierten Achsenschnitt und danach eine begrenzte Suche im Boardbereich.
Schaftabstände werden nach Kameravertrauen gewichtet; projizierte Änderungsstellen
liefern einen schwachen räumlichen Hinweis. Die Suche erfolgt zunächst mit 8 mm,
lokal anschließend mit 1 mm. Das Ergebnis wird ausdrücklich als unsicher
(`forcedDecision`, `needsReview`, Kameraanzahl und Residuum im Diagnosebericht)
gespeichert. Bildänderungen am Schaft sind keine präzise Messung der Eintrittsstelle.
Ohne verwertbare räumliche Daten ist die letzte Reserve eine unsichere 0-Punkte-
Entscheidung mit synthetischer Außenposition, keine gemessene Pfeilposition.

Automatische Würfe erhalten damit keinen verpflichtend zu korrigierenden
„Nicht erkannt“-Eintrag mehr. Die manuelle Meldung fehlender Würfe bleibt erhalten.
Referenzwechsel, Schutz vor Doppelzählung, Bouncer und Herausziehen bleiben aktiv.
Ohne beobachtbaren Wurfhinweis oder bei einem Kameraaufnahmefehler kann keine
Wurferkennung garantiert werden. Dauerhafte breite Handbewegungen lösen keinen
neuen Wurf aus. Eine konkrete Positionsschätzung ist nicht gleichbedeutend mit
bewiesener Erkennungsgenauigkeit.

Validierung: 95 bestehende Autoscorer-Regressionen einschließlich erweitertem
Zähltest sowie 3 neue Unit-Tests für einzelne/parallele Achsen und Außenrand-Miss
bestanden. `flutter analyze lib/features/autoscoring --no-pub` ohne Befunde.
Liveprüfung mit den drei USB-Kameras steht aus. Protokoll:
`build/autoscore_analysis/forced_decision_tests.log`.

Abschlussprüfung nach zusätzlichem Schutz vor veralteten Vorschlägen: 16 gezielte
Zähl-/Notentscheidungsfälle bestanden (`forced_decision_final_tests.log`).
Die abschließende Bereichsanalyse meldete zwei parallel hinzugekommene Stilhinweise
in `autoscore_audio_controller.dart` (Zeilen 81/88, curly_braces), keine Befunde
in der hier geänderten Entscheidungslogik. Audiodatei unverändert gelassen.
