# Abgesicherte Wiedererkennung für Fall 126 (2026-10-05)

## Ergebnis

Die zwölf tatsächlich gespeicherten Videoframes werden in zeitlicher Reihenfolge
mit den ursprünglichen Host-Zeitstempeln durch den produktiven Controller gespielt.
Korrekturwerte dienen ausschließlich zur Auswertung, nicht als Eingabe.

| Fall | Vor der Zusatzprüfung | Mit Zusatzprüfung | Benutzerkorrektur |
| --- | --- | --- | --- |
| 5 | T1 | T1 | T1 |
| 97 | 20 | 20 | 20 |
| 126 | MISS | T20 | T20 |

126 wird weiterhin beim achten gespeicherten Frame gezählt. Die alternative
Position liegt in den beiden entscheidenden Frames bei ungefähr
(-7,67; -103,40) und (-7,28; -104,27) mm. Kamera 1 und 3 liefern alternative
Schaftachsen; Kamera 2 liefert 10 beziehungsweise 13 neue Pixel im Kontaktbereich.
Die verdeckte Schaftansicht liefert sieben neue, verbundene Pixelsamples.
Die zusätzliche Prüfung benötigte im lokalen Replay rund 12–30 ms pro
betroffenem Frame. Das ist keine Messung der vollständigen USB-Wurf-Latenz.

## Schutzbedingungen

- Nur unsichere Außenrand-Schätzungen mit schwachen Achsen oder grob
  widersprüchliche Fits erhalten diese Zusatzprüfung.
- Kleine Kameraverschiebungen werden ausschließlich im sekundären Bildvergleich
  ausgeglichen: statische Kanten im Zahlenring, maximal 1,5 Pixel pro Richtung,
  mindestens 15 Prozent Verbesserung. Im Fall 126 war keine Verschiebung nötig.
- Frühere Dartpixel werden über den Unterschied zur Leerreferenz berücksichtigt.
  Auf beiden vorgeschlagenen Achsen müssen neue verbundene Pixelsamples liegen.
- Die dritte Kamera muss neue Pixel innerhalb von sechs Millimetern um den
  vorgeschlagenen Kontakt zeigen.
- Zwei verschiedene Bilder jeder Kamera müssen dieselbe Achsenpaarung,
  Score und Position innerhalb von drei Millimetern bestätigen.
- Widersprüchliche gleichwertige Alternativen werden abgelehnt.
- Zeitfenster maximal 180 ms; bestehende Entscheidungsfrist bleibt bestehen.
  Es gibt kein zusätzliches Warten auf einen beliebigen besseren Kandidaten.
- Diagnoseberichte enthalten `uncertainRecovery`, Ausrichtung, Kandidat,
  Bestätigung und Ablehnungsgründe. Kamerabilder bleiben im Original gespeichert.

## Prüfungen und Grenzen

242 Autoscoring-Tests bestanden. Ein neuer Regressionstest verwendet die
Originalbilder von Fall 126 und prüft außerdem wiederholte Zeitstempel,
fehlende unabhängige dritte Kamerainformation sowie bekannte Bildverschiebung.
Die 41 älteren Pakete (15 Korrekturen, 6 Batch 2, 4 Batch 3, 3 Batch 4,
13 Oktoberpakete) behalten ihre bisherigen Scores. Diese alten Stillbild-Replays
haben keine fortlaufenden Kamera-Zeitstempel und aktivieren daher die neue
zeitliche Freigabe nicht; bestehende Fehler in diesen Paketen bleiben offen.

Analyse: keine neuen Warnungen, nur vorhandener Style-Hinweis in
`test/manual_update_card_test.dart:35`. Windows-Build erfolgreich.

Keine neue Live-Wurfserie durchgeführt. Ein einzelner reparierter Diagnosefall
und unveränderte Regressionen belegen keine reale Gesamtgenauigkeit von 99,5 %.
Insbesondere dicht verdeckte Würfe und reale Außenrand-Misses benötigen weitere
Live-Videodiagnosen mit vollständig überprüften Ergebnissen.
