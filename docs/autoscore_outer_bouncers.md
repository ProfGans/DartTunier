# Bouncer am Außenrand

AutomaticBounceDetector prüft kurzzeitige Änderungen jetzt ab 18 Graustufen,
passend zur empfindlicheren Außenring-Erkennung. Neben genauer Achsenfusion
akzeptiert er eine unsichere Fusion oder zwei starke, ausreichend getrennte
Achsen mit gemeinsamem Schnittpunkt bis 300 mm vom Bull. Weitere starke
Achsen müssen diesem Punkt innerhalb von 12 mm zustimmen.

Es bleiben mindestens zwei veränderte Kameraansichten erforderlich. Die
Änderung muss innerhalb von 900 ms zur bisherigen Referenz zurückkehren;
gezählt wird erst beim stabilen Rückkehrbild und genau einmal. Ein Bouncer
ergibt 0 Punkte. Die reguläre Trefferfläche wird dadurch nicht erweitert.

38 Bouncer-, Controller-, Aufnahme- und Diagnose-Regressionstests bestanden.
Neue Fälle prüfen schwachen Kontrast bei 215 und 245 mm, Doppelzählung sowie
Ablehnung einer einzelnen oder paralleler Achsen. Kein Live-Kameratest.

Ein Abpraller, der in keinem aufgenommenen Bild erscheint, bleibt unerkennbar.
Die bisherige serielle Fotoaufnahme bietet keine lückenlose Videoerfassung.
