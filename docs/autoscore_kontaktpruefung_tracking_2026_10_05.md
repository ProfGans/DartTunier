# Kontaktprüfung und zeitlich bestätigte Schaftalternativen

05.10.2026

## Produktive Änderungen

Neue Korrektur-ZIPs enthalten pro kalibrierter Kamera eine
`kamera_N_kontaktpruefung.png` und eine versionierte JSON-Auswertung (Schema 1).
Die Originalbilder bleiben separat unverändert erhalten.

- Cyan: projizierte Double-/Triple-/Bull-Ringe, Segmentgrenzen und 230-mm-Suchgrenze.
- Gelb: gewählte Schaftachse.
- Pink: erkannter Kontaktpunkt.
- Grün: manuell korrigierter Punkt, zurückprojiziert in jede Originalkamera.
- JSON: Pixelpositionen, Sichtbarkeit, Abstand zu jeder Schaftachse,
  Positionsabweichung und Farbabdeckung der Ringmitten im ursprünglichen Leerbild.

Die Farbabdeckung prüft unabhängig vom Pfeil, ob projizierte Ringmitten auf
roten/grünen Bildbereichen liegen. Sie ist keine automatische Freigabe der
Kalibrierung und bestätigt weder Nummernausrichtung noch den echten Kontakt.
Ein geringer Rückprojektionsfehler bestätigt nur mathematische Konsistenz.

Die bestehende zeitliche Wiedererkennung wird zusätzlich bei grob
widersprüchlichen drei Kameraachsen aktiviert (eine Achse liegt mehr als 20 mm
neben der unsicheren vorläufigen Position). Sie verlangt weiterhin neue,
verbundene Pixel auf beiden Schaftachsen, lokale neue Pixel in der dritten
Kamera, zwei verschiedene zeitgestempelte Bilder jeder Kamera sowie stabile
Position, Score und Achsenpaarung. Neu wird auch die Richtungsstabilität beider
Schäfte geprüft (höchstens ungefähr 2,3 Grad Änderung zwischen den Frames).

Eine derartig bestätigte Alternative erhält bei der begrenzten zeitlichen
Auswahl unabhängige Drei-Kamera-Unterstützung: zwei Schäfte und lokale Pixel der
dritten Kamera. Die geometrische Schnittpunkt-Auswertung bleibt als zwei Views
protokolliert. Es gibt keine weitere Warteschleife und keine Übernahme eines
manuellen Sollwerts in die Erkennung.

## Original-Videofälle

| Fall | Vorher | Jetzt | Sollwert |
| --- | --- | --- | --- |
| 183 | 1 | 20 | 20 |
| 173 | 20 | 20 | 5 |
| 92 | 19 | 19 | 3 |

183 liefert in zwei Bildern eine Alternative nahe (16,6; -116,9) und
(16,2; -116,9) mm. Die dritte Kamera zeigt jeweils neun neue Pixel im
Kontaktbereich. Diese Alternative wurde früher bei der finalen Auswahl
verworfen; jetzt bleibt sie berücksichtigt.

173 und 92 sind weiterhin offen. Ihre manuell gesetzten Punkte liegen nahe
Segmentgrenzen; aus Kalibrierung und Achsen allein ist deren echter optischer
Kontakt nicht sicher rekonstruierbar. Die neuen Bilder erlauben nun den direkten
Vergleich. Keine fallnummernabhängigen Regeln oder manuellen globalen Offsets.

## Modellvorbereitung

`tool/autoscore_prepare_contact_labels_test.dart` erzeugt eine versionierte
Prüfliste: `build/autoscore_analysis/contact_label_review_v1.json`.
Aktuell enthält sie 36 unterschiedliche Capture-Ereignisse und 108 Kameraeinträge.
Doppelte Capture-Zeitpunkte werden ausgeschlossen. Identische Leerreferenz-
Gruppen bleiben in derselben vorgeschlagenen Train-/Validation-/Test-Aufteilung.
Das verhindert genau diese Form von Referenz-Duplikaten zwischen den Teilmengen;
ein unabhängiger Holdout aus neuen Setups bleibt zusätzlich nötig.

Pro Eintrag werden das Originalbild, der korrigierte Boardpunkt und ein aus der
bisherigen Kalibrierung vorgeschlagener Bildpunkt gespeichert. Echte Bild-
Spitzenmarkierung, Schaftendpunkte und Verdeckung sind noch unbestätigt.
`reviewed=false`, `trainingEligible=false`, `verifiedImagePoint=null` verhindern,
dass diese Vorschläge als geprüfte Trainingswahrheit gelten.

Kein neues Modell ist trainiert oder aktiviert. Dafür fehlen unabhängig am
Originalbild geprüfte Spitzen-/Schaftmarkierungen und ausreichend unabhängige
korrekte Würfe neben den bisherigen gezielt ausgewählten Fehlerfällen.

## Validierung

- 253 Autoscoring-Tests bestanden, einschließlich kompletten Originalvideos 183,
  42 und 20 sowie PNG-/ZIP-/JSON-Export und bisheriger Wiedererkennungs-Guards.
- Bisherige Videofälle 5, 97, 126, 42 und 20 bleiben T1, 20, T20, T5 und 20.
- Die 25 älteren gelieferten Diagnosepakete behalten ihre Scores.
- Neue Diagnosebilder aller neun Kamerafälle visuell erzeugt; Kamera-1-Bilder
  von 183, 173 und 92 visuell kontrolliert.
- Analyse enthält nur bestehenden Style-Hinweis in `manual_update_card_test.dart`.
- Windows-Build geprüft. Keine neue Live-Wurfserie; 99,5 Prozent nicht belegt.

Rohvergleich: `build/autoscore_analysis/contact_tracking_results.json`.
