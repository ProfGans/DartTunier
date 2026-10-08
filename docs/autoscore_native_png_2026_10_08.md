# Native Farbbilder und Latenz

Die Diagnose `autoscore_diagnose_1791446944854.zip` zeigt nach dem kompakten
Kameratransport eine native Abfrage von 34,309 ms statt zuvor 109,565 ms.
Beim letzten angenommenen Treffer benötigt die Bildaufbereitung noch 58,433 ms
für das Kamerapaket; zwischen erster Schaft-Evidenz und dem aktuellen Bild
liegen 241,66 ms. Diese Werte messen keine physische Treffer-bis-Sound-Latenz.

Die Kameracallbacks erstellen nun mit Windows Imaging Component verlustfreie
PNG-Farbbilder außerhalb des Kameramutex. Dart übernimmt diese direkt, statt
pro Frame ein RGB-Bild aufzubauen und JPEG zu codieren. Die vollständigen
Graupixel und die bisherige Farbbildgröße bleiben erhalten. Bei einem Fehler
des nativen Encoders bleibt der bestehende RGB/JPEG-Weg verfügbar.
Diagnoseexporte wandeln die Farbbilder erst beim Export in JPEG um.

## Messung mit echten Boardbildern

`flutter test tool/autoscore_native_png_verification_test.dart` nutzt drei
Farbbilder aus Fall 94 und den Release-C++-Probe-Encoder. Alle Farb- und
Graupixel stimmen exakt überein. Nach dem ersten Durchlauf liegt die
Dart-Verarbeitung pro Kamera bei etwa 14–20 ms im bisherigen Weg und
0,5–0,8 ms im PNG-Weg. Der native PNG-Encoder benötigt einschließlich seiner
Initialisierung 14–20 ms pro Kamera. Diese Arbeit läuft in den separaten
Kameracallbacks; sie ist keine kostenlose Operation. Der Test belegt keine
bestimmte Live-Trefferlatenz und ist kein AOT-End-to-End-Benchmark.

Messwerte stehen unter `build/autoscore_analysis/native_png_benchmark.json`.
Die Diagnose ergänzt `nativeColorEncodeMilliseconds` und
`nativeEncodedColorViews`, um den realen Aufwand bei laufenden Kameras prüfen
zu können. Die Erkennungs- und Bestätigungsschwellen wurden nicht verändert.

Für die Verwendung ist ein vollständiger Neustart der neu gebauten
Windows-App nötig, da sich die native Kamera-DLL geändert hat.
