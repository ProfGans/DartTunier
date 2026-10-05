# Dunkle Schäfte im schwarzen Außenring

Die reguläre Erkennung bleibt erhalten. Zusätzlich sucht FrameDetector im
schwarzen Außenring (170–230 mm, Referenzhelligkeit unter 80) nach verbundenen
Änderungen ab 18 statt 30 Graustufen. Die Bewegungsproben berücksichtigen diese
schwächeren Änderungen ebenfalls, damit die automatische Entscheidung starten
kann. Eine zusätzliche Ring-Achse steht auch dem Kameraabgleich zur Verfügung.

Die empfindlichere Achsensuche verlangt mindestens 48 Pixel, 95 Prozent
Linienunterstützung und ein geringes Verhältnis von Quer- zu Längsvarianz.
So erzeugt der gespeicherte Fall 9_2 trotz schwacher Bildstörungen weiterhin
keine neue Achse. Vereinzelte Rauschpixel werden bereits vor dem Fit verworfen.
Scoring endet unverändert bei 170 mm; festgestellte Außentreffer zählen 0.

Validierung: 78 Erkennungs-, Diagnose- und Controller-Tests bestanden, darunter
synthetische Außenring-Schäfte mit 22 Graustufen Kontrast sowie Rauschkontrolle.
Flutter analyze ohne Befund. Ein aktueller Praxistest mit USB-Kameras und
schwarzem Außenring liegt noch nicht vor.
