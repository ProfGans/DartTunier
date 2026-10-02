# Autoscorer-Prototyp

## Start

Im Hauptmenü öffnet **Autoscore-Tester** die automatische Drei-Kamera-Demo. Board leeren und **Kameras verbinden · automatisch starten** wählen. Nach erfolgreicher Kalibrierung wird die Leerboard-Referenz automatisch aufgenommen und die Erkennung gestartet. Erkannte Würfe werden ohne Bestätigung in Punktesumme und Verlauf übernommen, auch als unsicher eingestufte Treffer. Nach drei Pfeilen herausziehen; sobald alle drei Ansichten mehrfach ein ruhiges, leeres Board zeigen, beginnt die nächste Aufnahme automatisch. Auch das Herausziehen nach weniger als drei Pfeilen kann die Aufnahme zurücksetzen. Die Gesamtpunkte bleiben dabei erhalten. Es ist kein X01-Spiel nötig.

In der App: **Scorer → Autoscorer · drei Kameras**. In einem X01-Spiel öffnet das Kamera-Symbol den Autoscorer mit Übergabe bestätigter Einzeldarts an den bestehenden ScorerController.

1. Unter Windows werden drei USB-/UVC-Kameras bevorzugt vorausgewählt. Die Zuordnung kann manuell geändert werden und bleibt beim erneuten Suchen erhalten. Windows liefert keinen verlässlichen USB-Typ; die Vorauswahl nutzt Gerätenamen und externe Kameras als Ersatz. Anschließend verbinden. Falls Autodarts die Kameras exklusiv belegt, dessen Erkennung vorher beenden.
2. Nach dem Verbinden werden alle drei Kameras automatisch kalibriert. Die App erkennt rote/grüne Ringe und Bull, entzerrt die Perspektive und liest den Zahlenring mit der lokalen Windows-Texterkennung. Keine Punkte anklicken. Board leeren, Kameras starr montieren und den gesamten Double- und Zahlenring sichtbar halten. Bei einem Fehler die kamerabezogenen Hinweise beachten und **Automatisch neu kalibrieren** drücken.
3. Alle Darts entfernen, dann **Board ist leer · Erkennung starten**.
4. Einen Dart werfen, Hände aus dem Bild nehmen und auf den Vorschlag warten. Treffer am Board prüfen; bestätigen oder korrigieren. Erst danach den nächsten Dart werfen.
5. Nach drei Darts im Testmodus alle Darts entfernen und die Leerboard-Referenz neu aufnehmen. Bei X01 nach jedem abgeschlossenen Spielzug zum Match zurückkehren; den Autoscorer für den nächsten menschlichen Spieler erneut öffnen. Botzüge laufen im Match weiter.

Fehlwürfe und Abpraller ohne sichtbaren Dart können nicht automatisch erkannt werden; diese im normalen X01-Scorer erfassen. Falsch übernommene Treffer dort rückgängig machen. Falls ein Vorschlag durch eine Hand oder einen Schatten entstanden ist, nicht übernehmen: Kameras freigeben und mit leerem Board neu starten.

## Architektur und Verfahren

Eigenes Feature unter `lib/features/autoscoring`, mit Domain-Geometrie, Bilddetektor, Application-Controller, versionierter Kalibrierung und adaptiver Oberfläche. Keine neue Turnierengine, kein Autodarts-Login, keine Cloud-Verarbeitung und kein Python-Dienst.

`camera_windows` liefert drei Kameras. Da das Windows-Plugin keine Bildstreams unterstützt, werden Bilder nacheinander aufgenommen und in einem Hintergrund-Isolate auf Graustufen bei 320 Pixel Breite verkleinert. Temporäre Aufnahmedateien werden nach dem Lesen entfernt. Die Vorschau zeigt die zuletzt analysierten Bilder, keinen kontinuierlichen Videostream.

Die Kalibrierung extrahiert rote/grüne Pixel und entfernt große zusammenhängende Farbflächen des Auffangrings. Bei ungültiger Ringgeometrie wird automatisch ein zweites Farbprofil versucht: Es trennt getönte weiße Felder stärker von den Ringfarben und entfernt auch kleinere zusammenhängende Surround-Flächen am Bildrand. Der Bull wird separat mit dem empfindlicheren Rotfilter erkannt. Beide Profile müssen dieselben Geometrie- und Umfangsprüfungen bestehen; es werden keine geratenen Kalibrierpunkte freigegeben. Der kompakte rote Bull mit grünem Umfeld begrenzt die robuste Double-Ellipsen-Suche. Die Geometrie wird anschließend anhand beider Scoring-Ringe fein abgestimmt, damit kleine Änderungen von Licht und JPEG-Kompression die Kontur nicht verschieben. Eine projektive Kreistransformation zentriert den Bull und korrigiert Perspektive. Double- und Triple-Ring müssen ihre bekannten Radiusverhältnisse erfüllen.

Die Kameras werden mit `ResolutionPreset.high` geöffnet (am geprüften Aufbau 1280×720). Windows.Media.Ocr liest den Zahlenring in vier Drehungen, bei Bedarf auch aus dem Originalbild und aus aufgerichteten, überlappenden Zahlenausschnitten. Mindestens drei unterschiedliche Zahlen müssen dieselbe Ausrichtung ergeben. Erfolgreiche OCR-Kalibrierungen liefern lokal gespeicherte Bildreferenzen des gedruckten Zahlenrings (`autoscoring.reference.v1`, Schema und Geometrie-Revision 1, höchstens zwei Referenzen). Neue Aufnahmen können anhand des gesamten Zahlenrings und seiner Beschriftung daran ausgerichtet werden. Wiederholte Spielfeld-Segmente werden für diesen Abgleich ausgeschlossen; unklare Korrelationen und konkurrierende Ausrichtungen werden abgelehnt. Ringgeometrie und Bull werden für jede neue Aufnahme erneut berechnet, auch nach einem Kameraversatz. Noch nicht lesbare Ansichten können außerdem mit einer anderen erfolgreich kalibrierten Kamera abgeglichen werden.

Daraus entstehen automatisch vier normalisierte Referenzpunkte (20, 6, 3, 11) für die bestehende Board-Homographie. Alle drei Kameras müssen erfolgreich sein, bevor ihre Kalibrierungen gemeinsam gespeichert und die Treffererkennung freigegeben wird. Es wird keine Bildoberkante als 20 angenommen. Automatisch gelernte Zahlenring-Referenzen sind separat versioniert; das bisherige Kamera-Kalibrierungsschema bleibt unverändert.

Eine Leerboard- bzw. zuletzt bestätigte Referenz wird mit dem aktuellen Bild verglichen. Zwei ruhige Abtastungen vermeiden Vorschläge während deutlicher Bewegung. Nachbarschaftsfilter und PCA erkennen längliche Veränderungen als Dartachsen. Transformierte Geraden aus mindestens zwei Kameras werden mittels kleinster Quadrate geschnitten. Nahezu parallele Achsen, zu große Restabweichungen und Schnittpunkte außerhalb des Analysebereichs werden verworfen. Drahtnähe, fehlende dritte Ansicht und erhöhte Restabweichung kennzeichnen einen Vorschlag als unsicher. Im normalen Autoscorer und in X01 benötigen Vorschläge weiterhin Bestätigung. Im Autoscore-Tester werden gefundene Treffer automatisch übernommen. Eine separate Leerboard-Erkennung vergleicht die aktuelle Aufnahme mit der ursprünglichen leeren und der zuletzt gezählten belegten Referenz. Teilweises Herausziehen sperrt weitere Treffer, bis drei ruhige Leerboard-Abtastungen vorliegen; liegende Pfeile werden durch die aktualisierte Referenz nicht erneut gezählt.

Kalibrierung: SharedPreferences-Schlüssel `autoscoring.calibration.v1`, JSON-Version 1, Kamera-Gerätename plus Index der Geräteliste und vier Punkte. Das Schema bleibt kompatibel; die Punkte werden jetzt automatisch ermittelt. Bei jeder neuen Verbindung wird frisch kalibriert. Starke Weitwinkelverzerrung wird noch nicht korrigiert. Ein Windows-Sprachpaket mit OCR muss installiert sein. Unlesbare oder verdeckte Zahlen, farbige Hintergründe und sehr flache Kamerawinkel können die automatische Kalibrierung verhindern. Fehlgeschlagene Versuche ersetzen keine gespeicherte Kalibrierung und lassen die Treffererkennung gesperrt.

## Recherche

- [Autodarts: First Startup](https://autodarts.diy/getting-started/first-startup/): Kameraauswahl, Auflösung, Kalibrierungsmarker, Monitor-/Live-/Motion-Ansichten.
- [OpenCV steel darts](https://github.com/hanneshoettinger/opencv-steel-darts): Bilddifferenzen, Vor-/Nachverarbeitung und Zusammenführung mehrerer Kameraergebnisse. Konzeptuelle Orientierung; kein Quellcode übernommen.
- [OpenCV darts](https://github.com/vassdoki/opencv-darts): Mehrkamera-Trefferbestimmung mit seitlichen Kameras und Triangulation.
- [DeepDarts, CVPR Workshops 2021](https://openaccess.thecvf.com/content/CVPR2021W/CVSports/papers/McNally_DeepDarts_Modeling_Keypoints_as_Objects_for_Automatic_Scorekeeping_in_Darts_CVPRW_2021_paper.pdf): Kalibrierpunkte und Dartpositionen als lernbare Keypoints. Ein trainiertes Modell wäre eine spätere Erweiterung, ist hier nicht enthalten.
- [Windows.Media.Ocr](https://learn.microsoft.com/en-us/uwp/api/windows.media.ocr.ocrengine.recognizeasync): lokale Texterkennung über SoftwareBitmap, ohne Serverübertragung.

Der öffentlich dokumentierte Bedienablauf von Autodarts ist bekannt; dessen genaue proprietäre Erkennungslogik wurde nicht rekonstruiert. Der eigene geometrische Ansatz muss mit echten Kameraaufnahmen validiert werden. Synthetische Tests belegen Geometrie und Filterverhalten, keine Messgenauigkeit am physischen Board.

## Tests

Separater Hardwaretest ohne Turnier-/Konto-Bootstrap:

`flutter run -d windows --profile --target tool/autoscoring_preview.dart`

Diese Ansicht nutzt dieselbe Kamera- und Erkennungsimplementierung wie die App. Sie kann unabhängig von einer bereits laufenden Turnierverwaltung gestartet werden.

`flutter test test/automatic_calibration_test.dart test/autoscoring_test.dart test/autoscoring_controller_test.dart test/autoscoring_widget_test.dart`

Die echte native OCR-Pipeline kann unabhängig von Kameras mit `tool/autoscoring_ocr_probe.dart` geprüft werden. Den absoluten Berichtspfad als `--dart-define=OCR_REPORT_PATH=...` übergeben. Der Probe-Entrypoint zeichnet ein synthetisches Board mit Zahlen, führt die vollständige automatische Kalibrierung aus und prüft T20.

Zusätzlich `flutter analyze`, gemeinsame responsive Tests und Turnier-Simulationsmatrix. Vor einem produktiven Einsatz: alle 20 Segmente, Bull, Ringgrenzen, drei eng gruppierte Darts, verdeckte Schäfte, Hände im Bild, wechselndes Licht, Abpraller, Herausziehen und Kameratrennung an einem realen Board prüfen.

### Prüfstand 02.10.2026

46 Tests bestanden: automatische Kalibrierung mit gedrehten und perspektivischen Boardansichten, OCR-Koordinaten, Geometrie/Bildfilter, synthetischer Drei-Kamera-Ablauf, Freigabe bei Fehler/Disposal, Kalibrierungsschema, zwölf Autoscorer-Layoutfälle sowie gemeinsame adaptive Seiten-/Turniermatrix. Globale Flutter-Analyse ohne Befunde. Smartphone-/Desktop-PNG-Vorschauen mit Testbildern visuell geprüft.

Zusätzlich die echte Windows-OCR-Schnittstelle mit einem synthetischen Zahlen-Board ausgeführt: elf verschiedene konsistente Zahlen erkannt, automatisch kalibriert und T20 korrekt gewertet. Bericht unter `build/automatic_calibration_ocr.json`.

Nach dem gemeldeten Fehler am roten Auffangring: 61 Tests einschließlich Originalbildern und Folgeaufnahme der angeschlossenen USB-Kameras, gedrucktem Zahlenring-Abgleich, Ablehnung eines strukturlosen Zahlenrings, Referenzspeicherung, kompletter Controller-Übergabe, Layouts bis 200 Prozent Textskalierung und Turniermatrix bestanden. Globale Flutter-Analyse ohne Befunde. Die echte Kamera-/Windows-OCR-Pipeline wurde am angeschlossenen Aufbau mit 1280×720 geprüft: alle drei Kameras automatisch kalibriert. Bericht `build/autoscoring_camera_probe/report.json`; Referenz-Lernen aus Originalbildern in `build/original_camera_calibration_probe.json`. Dafür den Probe mit `OCR_CAPTURE_CAMERAS=true` ausführen; gespeicherte Originalbilder können separat mit `OCR_FIXTURE_DIRECTORY=...` geprüft werden. Reale Wurftests, Messgenauigkeit an Drahtgrenzen und Tests auf einem echten Smartphone bleiben offen.


Automatischer Testbetrieb: Replay-Tests mit synthetischen Drei-Kamera-Bildern prüfen drei Würfe, Doppelzählung, teilweises Herausziehen, Hand im Bild, leeres Board, Wiederanlauf und das Herausziehen vor dem dritten Pfeil. Das prüft den Zustandsablauf, nicht die Treffergenauigkeit des realen Boards. Der vollständige automatische Ablauf mit echten geworfenen Pfeilen wurde noch nicht praktisch geprüft.


Kalibrier-Regression 02.10.2026: Drei neue Kameraansichten aus dem gemeldeten Screenshot liegen unter `test/fixtures/autoscoring/shifted_1.png` bis `shifted_3.png`. Vor der Korrektur scheiterte die Ringgeometrie; nach der Korrektur bestehen sowohl die drei neuen Ansichten als auch die bisherigen Fotos und synthetischen Perspektiven. Der native Windows-Probelauf bestätigte die vollständige Kalibrierung aller drei neuen Ansichten mittels vorhandener Zahlenring-Referenzen (`build/autoscoring_shifted_probe/report.json`). Die Screenshot-Prüfung ersetzt keinen neuen Live-Durchlauf am physischen Board.


## Sichtbare Erkennungsdiagnose

### Flache Boardansicht und Positionskorrektur

Der Autoscore-Tester zeigt eine flache Ansicht aus den drei kalibrierten
Kamerabildern. Die inverse Homographie projiziert jedes Bild auf dieselbe
Boardebene in Millimetern; überlappende Ansichten werden gemischt. Die 20 ist
oben. Schäfte und Flights liegen außerhalb der Boardebene und können deshalb
versetzt oder mehrfach erscheinen. Die Trefferpunkte stammen aus der
gemeinsamen Achsenauswertung, nicht aus der gemischten Bilddarstellung.

Bild und Marker nutzen stets die gesamte quadratische Anzeigefläche, auch
wenn sie auf dem Desktop größer als das 480-Pixel-Projektionsbild ist.
Eine Darstellung des Bilds in seiner Originalgröße bei gleichzeitig
hochskalierten Markern würde die Punkte radial verschieben. Die gerenderten
Regressionstests in `test/flat_board_view_test.dart` vergleichen eine bekannte
Bildmarkierung mit ihrem Trefferpunkt bei 360 und 1440 Pixel Fensterbreite.

Ein Punkt kann mit Maus oder Touch gezogen werden. Bei eng benachbarten
Punkten erst den Treffer über seine Auswahl markieren; die Pfeilbuttons
verschieben ihn um 1 mm und sind per Tab/Enter bedienbar. Nach dem Loslassen
wird das Feld anhand der neuen Position berechnet, der Punktestand angepasst
und der Treffer als korrigiert gezählt. Beim Herausziehen verschwinden die
Punkte der aktuellen Aufnahme; Verlauf und gespeicherte Diagnosen bleiben.

Jede Positionskorrektur speichert automatisch eine Diagnose-ZIP. Über
„Diagnose-ZIP speichern“ im Trefferverlauf kann sie weitergegeben werden.
Berichtsversion 2 ergänzt `correctionPosition` mit `xMillimetres`,
`yMillimetres` und `source: flatBoard`; `hit` enthält weiterhin die ursprüngliche
Position. Alte Berichte der Version 1 bleiben unverändert auswertbar;
fehlende `correctionPosition` bedeutet, dass keine Positionskorrektur vorliegt.
`board_flach.png` enthält die Kamera-Projektion mit ursprünglichem Punkt in
Pink und korrigiertem Punkt in Grün. Die drei Originalbilder und
Erkennungsreferenzen werden weiterhin mit gespeichert.

### Auswertung der Korrektur-ZIPs vom 03.10.2026

Die automatische Kalibrierung justiert nach der Zahlenausrichtung den Winkel
an den Hell-Dunkel-Grenzen aller 20 Felder nach. Mehrere Radien je Grenze und
getrimmte Mittelwerte reduzieren den Einfluss von Pfeilen und Schatten. Die
Skalierung wird nur angepasst, wenn Double- und Triple-Ring übereinstimmen.
Die Feinjustierung läuft einmal im Kalibrierungs-Isolate, einschließlich der
Kalibrierung mit gespeicherten Referenzen, und liest keine Trefferkorrekturen.

| ZIP | Bisher erkannt | Korrigiertes Ziel | Wiederholung nach Feinjustierung |
| --- | --- | --- | --- |
| 25 | 7 | T7 | T7 |
| 39 | 3 | 19 | 19 |
| 54 | 13 | T13 | 13, weiterhin unsicher |
| 56 | 20 | 1 | 1 |
| 62 | 20 | 1 | 1 |
| 67 | T20 | T1 | T1 |
| 77 | 20 | 1 | 1 |
| 32 | Nicht erkannt | Nicht erkannt | Kein bekanntes Zielfeld; nicht gelöst |

In den vier 1/20-Fällen liefert Kamera 2 keine ausreichend eindeutige Achse.
Die beiden übrigen Ansichten liefern einen Punkt nahe der Feldgrenze; der
kleine Winkelversatz beeinflusst dort unmittelbar das Ergebnis. Bei Fall 54
liegt der neue berechnete Radius bei etwa 98,8 mm, knapp vor Triple ab 99 mm.
Die unsichere Grenze rechtfertigt keine pauschale Umwertung auf Triple.

Die sieben Fälle mit bekannten Zielfeldern liegen als Originalbilder,
Vorher-Referenzen und Berichte unter `test/fixtures/autoscoring/corrections`.
`test/autoscore_recorded_corrections_test.dart` prüft die sechs behobenen Fälle
und dokumentiert die verbleibende Unsicherheit bei 54. Synthetische Tests
prüfen Winkel-/Skalierungsfehler, ausgerichtete Boards und ungültige Bilder.
Das Ergebnis sechs von sieben betrifft ausschließlich diese ausgewählten
Fehlerberichte und ist keine allgemeine Genauigkeitsmessung. Die Wiederholung
justiert anhand der gespeicherten Trefferbilder; im Live-Betrieb wird das
leere Board kalibriert. Ein neuer Live-Wurftest steht noch aus. Nach dem
Starten der neuen Version das Board leeren und automatisch neu kalibrieren.

Die Kamerabilder zeigen standardmäßig die Erkennungsmarkierungen. **Erkennung in Kamerabildern anzeigen** blendet sie ein oder aus; **Erkannte Farbpixel zusätzlich anzeigen** zeigt eine ausgedünnte gelbe Farbmaske.

- Grün: freigegebene Double-/Triple-Ringe, Bull und Referenzpunkte 20/6/3/11.
- Orange: vorgeschlagene Geometrie oder bereits erkannte Ausrichtung, die noch nicht zum Zählen freigegeben ist. Auch verworfene Ellipsen bleiben sichtbar.
- Rot: Bull-Kandidaten bei uneindeutiger Bull-Erkennung.
- Blau/Cyan: Bildänderungen gegenüber der letzten Referenz und erkannte Dartachsen.
- Pink: zuletzt erkannter Treffer, auch nach automatischer Übernahme. Ein Fragezeichen kennzeichnet die bisherige Unsicherheitseinstufung. Beim erkannten leeren Board wird die Markierung entfernt.

Unter jeder Kamera stehen der Erkennungsschritt, das verwendete Farbprofil, die Zahl der Farbpixel und Bull-Kandidaten sowie die Double-/Triple-Abdeckung in 40 Winkelabschnitten. Vor der Ring-Prüfung wird die Abdeckung ausdrücklich als noch nicht geprüft bezeichnet. Bei aktiver Referenz erscheinen Bildbewegung und Anzahl ruhiger Abtastungen. Die Darstellung verwendet das Seitenverhältnis der tatsächlichen Aufnahme, zeichnet Treffer über die inverse Board-Homographie und beschneidet Dartachsen an den Bildrändern. Fehlgeschlagene Diagnosevorschläge aktivieren keine Treffererkennung. Die Beobachtungen sind flüchtig und ändern kein Speicherschema.

`test/camera_recognition_view_test.dart` prüft abgelehnte Kandidaten, Farbmasken und Ein-/Ausblenden bei 360x800, 800x600 und 1440x900 mit 100 und 200 Prozent Schrift. Optional gerenderte Vorschauen liegen unter `build/layout_previews/autoscoring_overlay_*.png`. Bull-Fehlerdiagnose, inverse Projektion und der Lebenszyklus der letzten Treffer-/Achsenmarkierung werden durch Domain- und Controller-Tests geprüft. Die Sichtprüfung mit Aufnahmen ersetzt keinen Live-Wurftest.

Die Ring-Suche prueft bei Stoerfarben am Zahlenring mehrere radiale Konturen. Jede Kontur muss weiterhin Double- und Triple-Ring im physikalisch passenden Radiusverhaeltnis nachweisen. Bei mehreren Bull-Kandidaten wird der zentrale Kandidat relativ zur groben Board-Ellipse geprueft; mehrere zentrale Kandidaten bleiben ein Kalibrierungsfehler. Regressionstests decken farbige Aussenmarkierungen und einen Bull-aehnlichen Fleck am Boardrand ab.

Ein deutlich zentraler Bull hat Vorrang vor weiteren Kandidaten: Seine Entfernung zur groben Board-Mitte muss kleiner als 0,35 Ellipsenradien sein; der naechste Kandidat muss mindestens 0,18 Radien weiter und mehr als doppelt so weit entfernt liegen. Alle Kandidaten bleiben fuer die Bilddiagnose erhalten. Zwei nahe beieinanderliegende zentrale Kandidaten bleiben uneindeutig. Die anschliessende Pruefung beider Scoring-Ringe bleibt erforderlich.

Falls die grobe Board-Mitte mehrere Bull-Kandidaten nicht unterscheiden kann, wird fuer jeden Kandidaten die vollstaendige Double-/Triple-Ring-Geometrie geprueft. Nur ein eindeutig geometrisch passender Kandidat wird uebernommen. Damit blockiert ein zusaetzlicher farbiger Fleck die Kalibrierung nicht allein wegen der Kandidatenanzahl; echte geometrische Mehrdeutigkeit bleibt ein Fehler.

Im Autoscore-Tester setzt das automatisch erkannte leere, stabile Board jetzt Punktestand und Trefferverlauf auf null. Das Ereignis wird einmal pro geleerter Aufnahme ausgegeben; teilweise entfernte Pfeile oder eine Hand vor dem Board loesen keinen Reset aus. Die naechste Aufnahme wird weiterhin automatisch erkannt.

Im Autoscore-Tester lassen sich erkannte Treffer ueber Richtig erkannt bestaetigen oder mit Korrigieren auf Single, Double, Triple, 25, Bull 50 oder Fehlwurf aendern. Die Genauigkeit ist der Anteil exakt richtig erkannter Segmente/Ringe an allen manuell geprueften Treffern. Ungepruefte Treffer werden separat ausgewiesen; ohne Pruefungen gibt es keinen Prozentwert. Wiederholte Pruefungen desselben Treffers erhoehen die Stichprobe nicht. Die Historie und Statistik bleiben beim Leeren des Boards in der geoeffneten Demo erhalten. Korrekturen alter Aufnahmen aendern nicht den Punktestand der aktuellen Aufnahme. Die Statistik erfasst erkannte Treffer, keine unentdeckten Wuerfe.

Die drei Kameras werden pro Aufnahmerunde parallel erfasst und dekodiert. Die zusaetzliche Polling-Pause betraegt 80 statt 350 ms; zwei stabile Beobachtungen bleiben erforderlich. Verbundene ein Pixel breite Differenzkanten werden fuer ueberlappende Pfeile ausgewertet, isolierte Rauschpixel verworfen. Im Tester gibt es keine Drei-Pfeil-Sperre; Herausziehen startet weiterhin automatisch die naechste Aufnahme. Regressionen pruefen vier ueberlappende Schaefte, keine Doppelzaehlung und teilweise Entfernung. Eine tatsaechliche Live-Latenz haengt vom Kamera-Treiber und der Snapshot-Dauer ab.

Fuer die Trefferposition wird das Kamerabild jetzt mit bis zu 480 statt 320 Pixeln Breite ausgewertet. Eine deterministische RANSAC-Suche isoliert die dominante schmale Schaftlinie, bevor PCA deren Achse bestimmt. Stoerpixel ausserhalb dieser Linie beeinflussen die Achse nicht mehr direkt. Die Fusion gewichtet Achsen anhand Linienunterstuetzung und Geradlinigkeit; die Restabweichung wird weiterhin ueber alle Kameras geprueft und unsichere Treffer bleiben markiert. Nahezu parallele Achsen werden verworfen. Regressionen decken Flight-aehnliche Stoerflaechen, eine ungenaue dritte Kamera und ueberlappende Pfeile ab. Eine Live-Genauigkeit muss anhand manuell gepruefter realer Wuerfe gemessen werden.

Korrektur fuer camera_windows 0.3.0: Bilddateinamen enthalten nur einen Zeitstempel in Millisekunden, keine Kamera-ID. Deshalb muessen takePicture, Einlesen und Loeschen kameraweise seriell erfolgen, damit gleichzeitige Aufnahmen keine Datei teilen. Die Dekodierung der bereits kopierten Bytes erfolgt weiterhin parallel. Erst wenn alle drei Bilder erfolgreich dekodiert wurden, werden neue Vorschaubilder gemeinsam veroeffentlicht. Regressionen verwenden einen gemeinsamen Dateipfad und absichtlich ungueltige Bilddaten.

Aktuelle Genauigkeitswertung: Beim Leeren der Aufnahme werden alle noch unkorrigierten Treffer automatisch als korrekt gewertet. Jede manuelle Korrektur markiert den Treffer dauerhaft als Fehler, auch wenn spaeter nochmals korrigiert wird. Die Statistik bleibt beim Herausziehen erhalten. Bei einer Korrektur speichert die App automatisch eine ZIP unter Dokumente/Autoscore-Diagnosen. Der Button Diagnose-ZIP speichern erlaubt die Auswahl einer Kopie zum Weitergeben. Die ZIP enthaelt Kamerabilder vom Erkennungszeitpunkt, eine gemeinsame Kamerauebersicht, vorherige und leere Graustufen-Referenzen sowie bericht.json (Schema 1) mit erkanntem/korrigiertem Ergebnis, Kalibrierpunkten, Achsenqualitaet und berechneter Position. Das Schreiben erfolgt im Hintergrund; Fehler beim Speichern aendern die uebernommene Korrektur nicht. Alte Aufnahmen lassen sich nach dem Herausziehen weiterhin korrigieren und exportieren.

Kurze sichtbare Schaftteile werden bei der 480-Pixel-Auswertung jetzt mit einer Mindestlaenge in Pixeln statt einer festen normalisierten Laenge gesucht. Der Tester bietet Nicht erkannten Pfeil melden: Tatsächliches Feld angeben, den fehlenden Treffer als Fehler in die Statistik aufnehmen und eine Diagnose-ZIP der aktuellen drei Kamerabilder sichern. Der nachgetragene Pfeil wird als neue Referenz uebernommen, damit er nicht spaeter nochmals automatisch gezaehlt wird.

Die Trefferfusion braucht jetzt zwei stabile Kameras; eine unruhige dritte Kamera blockiert diese Auswertung nicht mehr. Die Leer-Erkennung verlangt weiterhin drei ruhige Ansichten. Eine widersprechende dritte Achse wird nur dann verworfen, wenn ihre unabhaengig gemessene Qualitaet weniger als halb so hoch ist wie die der beiden guten Ansichten. Zwei gleich starke, widerspruechliche Ansichten werden nicht willkuerlich ausgewählt. Die Kameraansicht zeigt nur aktuell erkannte Achsen; alte Achsen bleiben in der Diagnose erhalten, werden aber nicht als aktuelle Beobachtung gezeichnet. Nach einer ausgebliebenen Erkennung kann die leere Referenz mehrere nachfolgende Pfeile enthalten; fuer diesen Fall ist eine Diagnose-ZIP aller Kameras erforderlich.

Die automatische Entscheidungsphase ist begrenzt: Nach drei erfolglosen Auswertungen mit ruhigem Bild und lokalen Aenderungen in mindestens zwei Ansichten wird eine gewichtete, berechenbare Position fest uebernommen und als unsicher markiert. Wenn keine geometrische Position bestimmbar ist, wird einmal Nicht erkannt mit null vorlaeufigen Punkten registriert und als Erkennungsfehler in der Statistik gefuehrt. Der Boardzustand wird in beiden Faellen zur Referenz fuer den naechsten Pfeil. Breite Handbewegungen loesen diesen Abschluss nicht aus. Diagnoseberichte enthalten forcedDecision. Unklares Ergebnis kann nachtraeglich korrigiert werden.

Beim automatisch erkannten leeren Board werden jetzt auch pending, vorherige Achsenreferenzen, Entscheidungszaehler, Aenderungspixel, Bouncer-Zwischenspeicher und Entfernungserkennung vollstaendig zurueckgesetzt. Bouncer werden heuristisch anhand einer kurzen, geometrisch passenden Schaftbeobachtung in mindestens zwei Kameras erkannt, die innerhalb von 900 ms wieder zur belegten Referenz zurueckkehrt. Nach stabiler Rueckkehr werden einmal Bouncer und 0 Punkte gezählt. Bouncer allein loesen auf einem ohnehin leeren Board keinen Herauszieh-Reset aus. Breitflaechige Bewegung oder Entfernung eines bereits gezaehlten Pfeils gilt nicht als Bouncer. Grenzen: Ein zwischen Snapshot-Aufnahmen vollstaendig erfolgender Abpraller ist damit nicht erkennbar; zuverlaessige Erkennung aller Bouncer benoetigt kontinuierliche Hochfrequenzbilder oder einen zusaetzlichen Sensor.
