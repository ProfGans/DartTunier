# Diagnosepakete vom 3. Oktober: dritte Serie

Die gespeicherten Bilder werden unter `test/fixtures/autoscoring/batch3` direkt mit der produktiven Erkennung nachgespielt.

| Paket | Befund | Ergebnis dieser Änderung |
| --- | --- | --- |
| Korrektur 63 | Zwei Achsen mit Qualität 0,893 und 0,709, etwa 6,6 Grad auseinander. Der Schnittpunkt liegt bei (115,89; -88,88) mm. | Nach der bestehenden Entscheidungsfrist unsichere Schätzung 4 statt vollständig fehlender Position. Abstand zum gesetzten Punkt etwa 5,54 mm. Keine Änderung der normalen, strengeren Erkennung. |
| Herausziehen 2 | Zwei Kameras leer; Kamera 1 behält nur 18 von 1120 alten Änderungspixeln, meldet aber 688 neue Pixel. Keine erkennbare Achse. | Begrenzte Restbild-Toleranz nach sechs ruhigen Beobachtungen. Eine tatsächlich weiterhin belegte dritte Kamera verhindert den Reset im Gegenversuch. |
| Korrektur 75 | Kamera 1 liefert eine starke, Kamera 3 eine schwache Achse. Schnittpunkt ergibt 9 statt der korrigierten 12. | Noch offen. Die bestehende Unsicherheitsmarkierung bleibt erhalten. Eine engere RANSAC-Toleranz verlor brauchbare Achsen und wurde verworfen. |
| Korrektur 9_2 | Korrektur MISS ohne gesetzte Position. Die aktuelle Referenz enthält bereits den nicht lokalisierten Wurf. Eine ältere Referenz liefert eine falsche Innenposition. | Noch offen; kein zuverlässiger schwarzer-Rand-Treffer aus diesen Achsen ableitbar. Keine erfundene Position. |

Die tolerantere Entscheidung benötigt genau zwei Achsen mit mindestens 0,7 Qualität, einen begrenzten Winkel und einen Schnittpunkt innerhalb des Erkennungsradius. Sie bleibt ausdrücklich prüfbedürftig. Zwei nahezu parallele schwache Achsen und Punkte außerhalb des Boards werden weiterhin verworfen.

Die zusätzliche Herauszieh-Toleranz setzt zwei unabhängig leere Ansichten voraus. In der dritten müssen mindestens 97 Prozent der alten Pfeilpixel verschwinden, die verbleibende Änderung unter 1,5 Prozent der Boardregion und unter 70 Prozent der vorherigen Änderung liegen. Eine erkennbare Achse verhindert diese Freigabe. Das ist eine Heuristik, keine Garantie gegen jede ruhige Verdeckung.

Die Wiedergabe fester Diagnosebilder prüft die Logik; die zeitliche Stabilität an den echten USB-Kameras muss anschließend erneut erprobt werden.
