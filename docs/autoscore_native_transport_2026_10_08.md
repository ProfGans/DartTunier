# Diagnose 1791445767774: Kameraübertragung

Die Datei meldet Revision `full-live-latency-measurement-2026-10-07` und
`buildMode: debug`. Der gespeicherte aktuelle Schritt befindet sich bereits
nach dem gezählten Dart: ein Treffer gezählt, derzeit keine brauchbaren Achsen.
Die Datei enthält deshalb keinen vollständigen Einschlag-bis-Sound-Nachweis.

Gemessener aktueller Aufnahmeweg:
- Kamera-Channel-Abfrage: 109,565 ms;
- Dekodierung/Farbaufbereitung: 78,514 ms;
- Achsenanalyse einschließlich Worker: 10,094 ms;
- restliche Entscheidung einschließlich Callback: 12,514 ms;
- native verworfene Bilder: 958; nach Synchronisierung übersprungene Pakete: 242.

Im Capture-Verlauf liegen wiederholt ungefähr 290–304 ms zwischen Gruppen
ausgewerteter Bilder. Der native Channel übertrug alle RGB-Bilder mit bis zu
1280 Pixel Breite. Seine gemeinsame Kamerasperre umfasste sowohl die komplette
Pixelkonvertierung als auch das Serialisieren/Senden der Antwort.

Änderung:
- volle Detailauflösung bleibt bis 1280 Pixel erhalten, übertragen als exakt
  dieselben ganzzahligen Graupixel wie zuvor im Dart-Decoder;
- RGB wird vor der Übertragung auf die ohnehin schon verwendete 640-Pixel-
  Farbauflösung gebracht, mit denselben Nearest-Neighbor-Samples;
- bei Kameras bis 640 Pixel bleibt der bisherige RGB-Transport ohne zusätzliche
  Graubildkopie erhalten;
- Konvertierung läuft außerhalb der gemeinsamen Kamerasperre; Generation und
  Zeitstempel werden vor dem Einreihen erneut geprüft;
- die Sperre wird vor dem Serialisieren/Senden der Antwort freigegeben;
- Synchronisierung, native Puffergröße und Trefferprüfungen bleiben erhalten.

Bei 1280×720 sinken die Pixelbytes pro Kamerabild von 2.764.800 auf 1.612.800
(41,67 Prozent). Das ist eine Messung der Datenmenge, keine zugesicherte
Reduktion der Einschlag-bis-Sound-Zeit. Der alte RGB-Channel bleibt kompatibel
mit dem neuen Decoder. Neue Diagnosen protokollieren die übertragenen Pixelbytes.

Ein nativer C++-Probe prüft alle Grau- und RGB-Samples für 1280×720, 1920×1080,
800×601, 320×240 und 1×1. Dart-Tests vergleichen die Erkennungspixel, JPEG-Bytes,
Seitenverhältnisse und Zeitstempel der alten und kompakten Transportvariante.
15 Transport-/Aufnahmetests sowie 39 bestehende Präzisions-/chronologische
Replay-/Bouncer-/Exporttests bestanden; sechs Exporttests einschließlich
Aufbewahrung des letzten Treffer-Timings ebenfalls bestanden.

Die Diagnose bewahrt jetzt zusätzlich das vollständige Timing des letzten
akzeptierten Treffers auf. Dadurch gehen dessen Messwerte nicht durch die
darauffolgenden Bereitschaftsbilder verloren.

Für die native Änderung die App vollständig schließen und die neu gebaute
Release-Version starten. Eine neue Live-Messung bleibt erforderlich.
