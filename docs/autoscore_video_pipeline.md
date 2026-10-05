# Video-Erkennung und unabhängige Prüfung

Die Windows-App verwendet nun kontinuierliche Vorschauframes der drei USB-Kameras.
Die lokale BSD-lizenzierte Kopie von camera_windows unter packages/camera_windows
ergänzt den Kanal dart_tournament/autoscore_video. Die normale Kamera-API bleibt
erhalten. Auf Plattformen ohne diese Erweiterung bleibt die Einzelbildaufnahme.

Jede Kamera puffert maximal sechs RGB-Frames, höchstens 1280 Pixel breit und
höchstens 50 pro Sekunde. Die tatsächliche Bildrate hängt von Kamera und USB ab.
Die Erkennung verarbeitet Dreiergruppen mit maximal 40 ms Zeitunterschied;
veraltete und doppelte Frames werden verworfen. Gemessen wird die Ankunft am PC
auf einer gemeinsamen monotonen Uhr, keine Hardware-Synchronisation. Der
Decoder läuft außerhalb des UI-Isolates. Fehlende gemeinsame Bilder für mehr
als 2,5 Sekunden melden einen Aufnahmefehler statt still weiterzuwarten.

Die Spitzensuche prüft zusammenhängende Differenzpixel an tatsächlichen
Schaftenden in voller Auflösung. Nur übereinstimmende Endpunkte aus mehreren
Ansichten korrigieren die bisherige Achsenschnitt-Schätzung. Bei verdeckten
Spitzen bleibt die bisherige zeitlich begrenzte Entscheidung verfügbar.

Die räumliche Kontaktprüfung verwendet drei Kamerastrahlen und dokumentiert
ihre Annahmen: Bildhauptpunkt im Zentrum, quadratische Pixel, zuvor entzerrte
Bildpunkte. Unplausible Kameraposen oder widersprüchliche Strahlen werden
verworfen. Eine über der Boardebene liegende Spitze nahe einem bestehenden Dart
gilt erst nach wiederholter Bestätigung als Robin-Hood-Hinweis mit 0 Punkten.
Diese Prüfung ist experimentell; sie ersetzt keine gemessenen Kameraintrinsiken
und keine Prüfung mit echten Robin-Hood-Würfen.

Die automatische Kalibrierung nutzt Double- und Triple-Ringpunkte aus vielen
Sektoren. Separate Sektoren prüfen die Verbesserung der perspektivischen
Abbildung und radialen Objektivkorrektur. Auch der abschließende Fit muss diese
Verbesserung erhalten. Diagnosewerte nennen Beobachtungsanzahl, Ringfehler und
Objektivparameter; große Änderungen an der Boardgeometrie werden abgelehnt.

Diagnose-ZIPs ab Schema 7 enthalten echte Farbbilder zusätzlich zu Graustufen,
eine kurze Vorher-Sequenz und bis zu vier weitere Frames nach der Entscheidung,
soweit diese vor Export vorliegen. Frames erhalten Zeitstempel und Sequenznummern.
Aus mindestens zwei Farbbildern entsteht zusätzlich pro Kamera eine abspielbare
GIF-Sequenz; die Einzelbilder bleiben für die Analyse in höherer Auflösung erhalten.
Berichte enthalten Zeitversatz, verworfene Bilder, Verarbeitungszeiten,
Spitzenbeobachtungen und räumliche Kontaktprüfung. Ältere Graustufenaufnahmen
können nachträglich keine echten Farben oder fehlenden Zwischenbilder liefern.

Im Autoscorer-Menü und Tester gibt es eine unabhängige Prüfstatistik. Sie zählt
nur ausdrücklich bestätigte oder korrigierte Würfe. Herausziehen bestätigt
weiterhin die bisherige Alltagsstatistik, zählt aber nicht als unabhängige Prüfung.
„Kein echter Wurf“ entfernt eine Fehlmeldung aus der Aufnahme und zählt sie als
Fehler. Nachgemeldete fehlende Würfe zählen ebenfalls als Fehler. Prüfserien
können neu gestartet und als JSON exportiert werden; bisherige Setup-Zähler
bleiben erhalten. Setup-Schema 2 liest Version 1 ohne erfundene Prüfergebnisse.

Für die Prüfserie jeden tatsächlichen Wurf kontrollieren, auch Außenrand,
Abpraller und enge Gruppen. Prüfaufnahmen dürfen nicht gleichzeitig zur Anpassung
der Erkennung dienen. Der angezeigte einseitige exakte 95%-Grenzwert berücksichtigt
die Stichprobengröße. Selbst 600 vollständig geprüfte fehlerfreie Würfe erreichen
erst knapp die untere Grenze von 99,5 %. Repräsentative unabhängige Aufnahmen
sind zusätzlich erforderlich; Softwaretests allein belegen diese Genauigkeit nicht.
