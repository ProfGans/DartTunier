# Vorzeitige Herauszieh-Sperre

Die Diagnose 1791447600181 zeigt einen gezählten T20 und eine aktive
Herauszieh-Sperre. Der Moment, der die Sperre auslöste, ist nicht enthalten.
Im letzten Zustand bleiben 82–91 Prozent der vorher belegten Pixel erhalten;
gleichzeitig kommen deutlich neue Pixel hinzu. Die bisherige Rückkehrprüfung
erforderte fast identische Bilder ohne neue Pfeile und konnte damit blockieren.

AutomaticVisitReset prüft nun zusätzlich, ob mindestens 97 Prozent der alten
belegten Pixel in jeder Kamera innerhalb eines Pixels noch Unterstützung haben.
Neue Pixel dürfen hinzukommen, aber höchstens das Dreifache der bisherigen
Belegung: Eine großflächige Hand darf keine Wiederherstellung vortäuschen.
Nach drei ruhigen Bildpaketen wird eine vorzeitige Sperre gelöst, sofern das
konfigurierte Wurflimit noch nicht erreicht ist. Die Referenzen und gezählten
Treffer werden dabei erhalten; echte Leer-Erkennung bleibt unverändert.

Regressionen prüfen verschobene Schäfte plus weiteren Pfeil nach einem und
zwei Würfen, die weiterhin gesperrte vollständige Aufnahme, echte Teilentnahme,
unabhängige neue Pixel sowie eine Hand vor den alten Schäften.
Ein Live-Test mit dem konkreten Aufbau bleibt erforderlich.
