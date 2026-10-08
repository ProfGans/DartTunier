# Fall 94 und Verarbeitungslatenz

Fall 94 wurde ohne Korrekturdaten mit der Produktionspipeline wiedergegeben.
Vorher: Single 20. Nachher: T20. Der Fall ist als chronologischer Regressionstest
mit den ursprünglichen Kamerabildern hinterlegt.

Zwei Spitzenbeobachtungen lagen eng zusammen am Triple-Ring. Die dritte
Beobachtung lag mehr als 12 mm davon entfernt und hatte am geschätzten Kontakt
kaum neue Pixel, aber bereits belegte Pixel. Diese widersprüchliche Ansicht
darf die Prüfung der lokal gemessenen Ringkante nicht blockieren. Die übrigen
Bedingungen bleiben bestehen: zwei passende Spitzen, messbare Ringkante und
frische Kontaktpixel in zwei Ansichten. Eine tatsächlich unabhängige, starke
Drei-Kamera-Bestätigung bleibt geschützt.

Die Diagnose meldete 207 ms Verarbeitung, obwohl die einzelnen Bildschritte
meist zusammen ungefähr 20–30 ms benötigten. Das synchrone Komprimieren der
Diagnosebilder nach dem akzeptierten Treffer blockierte die nächste Aufnahme.
Die Bilder werden jetzt sofort kopiert und anschließend seriell im Hintergrund
verlustfrei komprimiert. Der Export kann bei Bedarf synchron fertigstellen.
Unveränderte Referenzbilder der Herauszieh-Erkennung werden zusätzlich anhand
ihrer Identität zwischengespeichert; neue Referenzen oder Kalibrierungsbereiche
verwerfen den Cache automatisch.

Lokaler Benchmark mit 24 Detailbildern aus Fall 94 (22.118.400 Pixel):
- vorher synchrone Kompression: 187,281 ms;
- jetzt Kopieren im Erkennungspfad: 7,783 ms;
- komprimierte Bytes und entpackte Pixel stimmen exakt überein.

Dies misst die blockierende Diagnosesicherung, nicht die gesamte Zeit vom
Einschlag bis zur Anzeige. USB-Aufnahme, Bildstabilisierung und zeitliche
Bestätigung benötigen weiterhin Zeit. Eine Live-Latenz oder eine Genauigkeit
von 99,5 Prozent ist damit nicht nachgewiesen.

Verifikation: 250 Autoscoring-Tests bestanden; separater Verlustfreiheits- und
Laufzeitbenchmark bestanden. Die 25 alten Stillbild-Replays liefern unveränderte
Ergebnisse gegenüber `ordner9_user_old_25.json`; bestehende Fehlfälle sind damit
nicht behoben. `flutter analyze` meldet lediglich den bereits vorhandenen
Style-Hinweis in `test/manual_update_card_test.dart:35`. Algorithmusrevision:
`nonblocking-evidence-ring-contact-2026-10-07`.
