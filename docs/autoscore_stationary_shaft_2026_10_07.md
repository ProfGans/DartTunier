# Früherer Auswertungsbeginn bei ruhiger Pfeilachse

Die bisher genannten 8 ms betreffen nur die Kopie der Diagnosebilder. Sie sind
keine Messung von Einschlag bis Sound und erklären die gemeldete Sekunde nicht.
Die Farbbildaufbereitung kostet im lokalen Vergleich rund 37–42 ms je drei
Kameras; die reine Diagnoseprotokollierung unter 0,1 ms pro Beobachtung.

Der Controller wartete bisher auf zwei Beobachtungen mit weniger als 0,2 Prozent
Bildänderung. Bei Vibrationen kann diese Bedingung verzögert erfüllt werden,
auch wenn die sichtbare Pfeilachse bereits stabil ist. Der neue zusätzliche
Einstieg verlangt zwei verschiedene Zeitstempel mit höchstens 100 ms Abstand,
dieselbe Board-Referenz, Achsenqualität mindestens 0,9, Bildbewegung unter 0,6
Prozent in beiden Beobachtungen, Winkeländerung höchstens ungefähr 0,29 Grad
und Verschiebung der normalisierten Linie höchstens 0,7 mm.

Dies startet die bestehende Auswertung früher. Die zeitliche Bestätigung der
Trefferposition und die Geometrie-/Kontaktprüfungen bleiben bestehen. Eine
ruhige Achse ist alleine kein akzeptierter Treffer. `stationaryShaft` wird im
Diagnoseverlauf pro Kamera protokolliert. Referenzwechsel, alte/fehlende
Zeitstempel, Handbewegung und schwache/verschobene Achsen sind ausgeschlossen.

Die 30 gezielten Tests für Achsenstabilität, chronologische Problemfälle,
zeitliche Auswahl und Bouncer bestanden. Die breitere Autoscoring-Suite wurde
mit sieben Fehlern in `autoscorer_page_test.dart` und einem anschließend
nicht abschließenden Scorer-Test abgebrochen. Sie ist deshalb nicht als grün
zu bewerten. Die neuen Domain- und Replay-Tests waren dort bereits erfolgreich.

Eine weitere getestete Idee, ein dauerhaft laufender Bilddecoder, brachte im
Vergleich keine Beschleunigung (etwa 50 ms je Paket in beiden Varianten) und
wurde nicht übernommen. JPEG wurde nicht durch PNG ersetzt, da der gemessene
Speicherbedarf der Farbbilder dadurch stark zunahm.

Eine konkrete Einschlag-bis-Sound-Latenz und eine Genauigkeit von 99,5 Prozent
sind nicht nachgewiesen. Die Release-Version muss weiterhin live geprüft werden.
