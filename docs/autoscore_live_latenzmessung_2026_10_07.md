# Vollständigerer Laufzeitbericht

Die bisherigen Teilmessungen erklären die vom Nutzer weiterhin gemeldete
Verzögerung von mindestens einer Sekunde nicht. Die Erkennung gilt damit nicht
als ausreichend beschleunigt. Keine weiteren Entscheidungsschwellen wurden in
diesem Schritt verändert.

Neue Diagnosewerte unter `hit.performance.liveFrame`:
- Bildalter beim nativen Auslesen, Wartedauer nach Rückkehr des Kamera-Channels;
- Grau-/Farbbildaufbereitung einschließlich des Decoders;
- Achsenanalyse einschließlich Hintergrund-Worker und Datenübergabe;
- Entscheidungsverarbeitung einschließlich Treffer-Callback;
- Treffer-Callback separat, einschließlich der dort erfolgenden Diagnosesicherung;
- Zeit vom zuerst beobachteten Schaftnachweis in mindestens zwei Kameras bis zum
  aktuellen Entscheidungsbild, gemessen anhand der Capture-Zeitstempel;
- Audio-Warteschlange und Dauer der Übergabe an die Audioausgabe.

Der Frame-Bericht bleibt nach dem Capture-Callback referenziert, bis seine
Messungen abgeschlossen sind. Jeder neue Frame erhält ein eigenes Objekt;
spätere Würfe verändern die gespeicherten Messungen eines früheren Wurfs nicht.
Die Änderung ist additiv zum bestehenden Diagnoseformat.

Die Zeit vor Ankunft der Bilder auf dem PC und der tatsächliche physische
Audio-Onset werden nicht gemessen. Die Ausgabe meldet diese Grenzen explizit.
Der Audio-Dispatch ist die abgeschlossene API-Übergabe, kein Nachweis für den
Zeitpunkt, an dem ein Lautsprecher hörbar wird. Die Kamera-Altersschätzung
schließt die Channel-Rückübertragung nicht vollständig ein.

Benötigt wird eine neue, nach dem langsamen Treffer erstellte Diagnose aus der
Release-Version dieser Revision. Die alte Diagnose 94 besitzt diese Werte nicht.
Tests prüfen insbesondere das Nachtragen abgeschlossener Messwerte und die
Isolation zwischen aufeinanderfolgenden Würfen. Die bestehenden chronologischen
Treffer-/Bouncer-Replays liefern weiterhin ihre erwarteten Ergebnisse.
