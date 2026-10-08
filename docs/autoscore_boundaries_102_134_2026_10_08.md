# Grenzfälle 102 und 134

Beide ZIPs wurden unter `build/autoscore_analysis/boundaries_102_134` entpackt
und mit `tool/autoscore_new_video_replay_test.dart` ohne Korrekturfeedback
nachgespielt. Baseline: 102 liefert 1 statt T1, 134 liefert 19 statt 3.

Bei 134 lag der Radius im pauschal ausgeschlossenen Bereich der lokalen
Segmentmessung. Dieser Ausschluss wurde durch Messungen im angrenzenden
Single-Feld ersetzt. Die größere radiale Probe wird ausschließlich im zuvor
ausgeschlossenen Bereich verwendet: Eine allgemeine Erweiterung verschlechterte
den bekannten Fall 27 und wurde nicht übernommen.

Im neuen Messweg findet 134 die Segmentgrenzen aller drei Kameras, entscheidet
aber weiterhin 19. Der Endpunkt aus Kamera 3 ist nur knapp auf der anderen
Seite, und die unabhängige lokale Bestätigung reicht nicht aus.

Ein experimenteller Ein-Endpunkt-Ringweg für 102 wurde zurückgenommen. Nur
Kamera 3 liefert lokale neue Kontaktpixel; die anderen Kameras liefern dort
keine ausreichende unabhängige Bildbestätigung. Eine Schwellenlockerung oder
eine Verschiebung anhand des gespeicherten Korrekturpunkts wurde nicht eingebaut.

## Ergänzende Lösung: gemessener Endpunkt

Der neue Service `boundary_endpoint_contact.dart` berücksichtigt einen nahen
sichtbaren Endpunkt, wenn die bisherige Endpunkt-Fusion widerspricht. Er verlangt
neue Kontaktpixel in dieser Ansicht, zwei nicht parallele Schaftachsen, zwei
unabhängig gemessene Ring-/Segmentkanten und einen widersprüchlichen entfernten
Endpunkt ohne frische Kontaktpixel an der vorgeschlagenen Stelle. Mehrdeutige
Kandidaten und Überschreitungen mehrerer Grenztypen werden zurückgewiesen.
Der Schaftabstand verwendet dieselbe 3-mm-Toleranz wie die lokale Segmentprüfung;
die Spitze muss mindestens .85 Achsenqualität haben. Die schwächere zweite
Achse muss mindestens .45 Qualität besitzen und geometrisch unabhängig sein.

Die zeitliche Entscheidung erhält einen gemessenen Kontakt über das begrenzte
Drei-Bild-Fenster, auch wenn später zwei unbestätigte Achsenschätzungen überein-
stimmen. Drei unabhängig unterstützte Kameraachsen behalten Vorrang. Eine bereits
lokal bestätigte Zwei-Achsen-Entscheidung wartet nicht zusätzlich auf die dritte
Kamera; die reguläre zeitliche Bestätigung bleibt aktiv.

Der abschließende Replay `endpoint_solution5.json` liefert **T1 für 102 und 3
für 134**. Beide Fälle sind als unveränderte Bildfixtures und automatische
Controller-Tests aufgenommen. Korrekturpositionen dienen ausschließlich der
Auswertung und sind keine Eingabe für die Erkennung. 72 Treffer-/Reset-Tests
und 30 zusätzliche Tests älterer Diagnosefälle bestehen. Dies belegt keine
99,5-Prozent-Genauigkeit im Live-Betrieb; der Test mit echten Kameras steht aus.
