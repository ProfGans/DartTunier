# Prüfung der Diagnosen 27 und 89

Quellen: `Downloads/Neuer Ordner (7)/autoscore_korrektur_27.zip` und
`autoscore_korrektur_89.zip`, Berichtsschema 8.

Die zwölf gespeicherten Bildsätze je Fall wurden mit aktuellen Produktions-
Erkennungsmethoden und Original-Zeitstempeln abgespielt. Korrekturpunkte dienen
nur zum Vergleich, nicht als Eingabe der Erkennung. Der Replay rekonstruiert
die Bildreferenzen, nicht die gesamte vorherige Live-Sitzung.

| Fall | Live erkannt | Korrigiert | Replay |
| --- | --- | --- | --- |
| 27 | 19 | 3 | 19 |
| 89 | 20 | T20 | 20 |

Beide Fehler sind weiterhin reproduzierbar. Der erfolgreiche technische
Testlauf bedeutet hier nicht, dass die Treffer korrekt erkannt wurden.

## Fall 89: Schwächere spätere Schätzungen verdrängen zwei Kameraachsen

Erster Entscheidungskandidat: (-15,09; -104,82) mm, zwei Kameras,
entspricht T20. Danach (-16; -115) und (-15; -114) mm, jeweils nur eine
Kamera; deren Übereinstimmung führt zu `consecutiveAgreement` und 20.
Manuelle Korrektur: (-12,86; -103,71) mm. Positionsabweichung der endgültigen
Schätzung ungefähr 10,5 mm. Spitzenprüfung: `insufficientTipViews`.

Die gelbe Achse und die beiden Markierungen in der Kontaktprüfung passen zu
einer falschen Längsposition auf ungefähr derselben Schaftachse. Als nächstes
sollte die zeitliche Entscheidung eine zuvor unabhängiger gestützte Position
gegen späteren Verlust von Kameras absichern. Zwei Achsen mit Nullresidual
allein beweisen jedoch keinen korrekten Kontakt: zusätzliche zeitliche oder
lokale Pixelunterstützung bleibt notwendig. Eine pauschale Bevorzugung aller
frühen Zwei-Kamera-Schätzungen wäre nicht ausreichend abgesichert.

## Fall 27: Segmentgrenze bei widersprüchlichen Spitzen

Erkannt (-19,30; 115,85) mm, korrigiert (-15,43; 116,57) mm: ungefähr
3,94 mm Unterschied, ausreichend für den Wechsel 19 → 3.
Die drei gewählten Achsen haben Konfidenzen ungefähr 0,49, 0,99 und 0,98;
der gemeinsame Residualfehler liegt bei 0,83 mm. Trotzdem bestätigt der
kleine Residualfehler nicht die richtige Position auf dem realen Board.
Die zwei Spitzenbeobachtungen unterscheiden sich ungefähr 15,4 mm;
`tipViewsDisagree` verwirft die Verfeinerung. Eine Spitze aus Kamera 3 liegt
ungefähr 1,65 mm vom manuellen Punkt entfernt, genügt allein aber nicht als
unabhängiger Beweis.

Nächster Ansatz: bei Segmentgrenzen lokal Kontakt und kalibrierte Drahtgrenze
in den Originalbildern prüfen, statt pauschal 19 → 3 zu verschieben oder die
schwächste Kamera immer auszuschließen. Auch starke Achsen können durch
Verdeckung oder Schaftmodell systematisch versetzt sein.

Kontaktprüfungen von Kamera 1 (89) und Kamera 3 (27) wurden visuell geprüft.
Aus diesen zwei Fällen folgt keine Aussage zur Gesamtgenauigkeit.
An der Trefferlogik wurden bei dieser Prüfung keine Änderungen vorgenommen.

Ergebnisse: `build/autoscore_analysis/new_27_89_results.json`.
Replay-Protokoll: `build/autoscore_analysis/new_27_89_replay.log`.
