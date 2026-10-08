# Begrenzte Gruppenspiele

Unter **Gruppenoptionen → Spiele pro Spieler begrenzen** lässt sich für jede Jeder-gegen-jeden-Gruppe eine Obergrenze einstellen. Beim Einschalten ist sie fünf. Die Begegnungen werden vor Turnierbeginn ausgewogen geplant und mit der normalen Ergebnis-, Gruppenwertungs- und Qualifikationslogik ausgespielt. Auch der Formatfinder bietet begrenzte Gruppen mit maximal fünf Spielen an.

Bei zwölf Spielern sind fünf Spiele je Spieler möglich. Bei dreizehn Spielern sind insgesamt 32 Begegnungen möglich: zwölf Spieler spielen fünfmal, einer viermal. Niemand überschreitet die Obergrenze. Freilose zählen nicht als gespielte Begegnungen. Wiederholungen und separate K.-o.-Etappen bleiben eigene Einstellungen.

Der Challonge-Spieltag DCUH202601 verwendet Swiss mit fünf Runden und anschließendem Finale. Der Import erkennt den Gruppenmodus, übernimmt die 30 tatsächlichen Gruppenspiele und das Finale und ergänzt fünf aus vollständigen Quellrunden erkennbare Freilose für die Swiss-Wertung. Die App berechnet ihre eigenen Tabellen und zeigt Unterschiede zu offiziellen Challonge-Plätzen im Vergleichsbericht. Die historische Ergebnisquelle bleibt erhalten. Die vorhandene optionale Elo-Auswahl gilt weiterhin.

Speicherschema 22 ergänzt `groupMaxGamesPerPlayer`. Fehlende oder leere Werte bedeuten weiterhin vollständiges Jeder gegen jeden; die Migration sichert den bisherigen Speicher. Die Entwicklungsmatrix prüft begrenzte Gruppen mit zwölf und dreizehn Spielern einschließlich Weiterkommen zum Finale.
