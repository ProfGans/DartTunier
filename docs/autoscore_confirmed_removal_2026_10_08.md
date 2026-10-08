# Diagnose 1791461220924: vorzeitige Herauszieh-Sperre

Die Release-Diagnose nutzt die native PNG-Verarbeitung. Beim letzten angenommenen
Treffer: native Abfrage 2,383 ms, native PNG pro Kamera 8,177–9,106 ms,
Dart-Bildaufbereitung 1,756 ms, Verarbeitung nach Kanalantwort 31,49 ms.
Die Schätzung von PC-Bildankunft bis Verarbeitungsende beträgt 59,958 ms;
dies ist keine gemessene physische Treffer-bis-Sound-Latenz.

Nach einem gezählten Single 20 wartet das System auf Herausziehen. Die letzten
Frames zeigen keine Entnahme und wachsende Belegung. Die genaue Auslösung der
Sperre liegt außerhalb des gespeicherten Zeitfensters. Ein neuer Regressionstest
setzt deshalb ausdrücklich eine unbestätigte Sperre und spielt anschließend die
acht gespeicherten Bildpakete mit Originalkalibrierungen ab.

Eine Entnahme wird weiterhin sofort vorsorglich gesperrt, sobald zwei Kameras
entsprechende Änderungen sehen. Dauerhaft bestätigt wird sie erst nach zwei
ruhigen Bildpaketen mit Entnahme-Evidenz. Solange das nicht passiert ist, dürfen
drei ruhige Bildpakete ohne Entnahme die Vorsichtssperre aufheben, wenn in allen
drei Ansichten mindestens 75 Prozent der alten belegten Pixel im lokalen
Ein-Pixel-Umfeld erhalten sind. Neue Pixel bleiben begrenzt, damit eine Hand
nicht als wiederhergestellter Pfeilbestand zählt.

Bei bestätigter Teilentnahme gilt weiterhin die strengere Wiederherstellungs-
prüfung. Das konfigurierte Wurflimit und die Leer-Erkennung bleiben erhalten.
Gezählte Treffer und Kamera-Referenzen werden beim Aufheben einer Vorsichtssperre
nicht gelöscht. Die Diagnose ergänzt `removalDecision` mit Wurflimit,
bestätigter Entnahme, Ansichtszahlen und ruhigem Zustand.

Der Regressionstest mit den echten Bildern löst die unbestätigte Sperre, ohne
das belegte Board als leer zu melden. Zusätzliche Tests verhindern das Aufheben
bei bestätigter Teilentnahme, Handverdeckung und erreichtem Wurflimit.
