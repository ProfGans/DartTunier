# Diagnoseauswertung und Beschleunigung – 5. Oktober 2026

## Datengrundlage

13 gelieferte ZIPs wurden gelesen und mit den gespeicherten Kalibrierungen,
Referenzbildern und Detailbildern durch den produktiven Controller abgespielt.
Nummer 6 und 7 sind zwei Exporte desselben Ereignisses (gleiche Capture-Zeit).
Es bleiben 12 unterschiedliche Ereignisse, darunter der ältere Rotationsfall
`autoscore_korrektur_1`. Dies ist eine Auswahl von Korrekturen, keine repräsentative
Stichprobe aller Würfe und kein Nachweis einer allgemeinen Genauigkeitsquote.
Die eingezeichneten Positionen sind Benutzerangaben und können selbst ungenau
sein. Der Replay liest sie nur zur Auswertung, niemals zur Trefferentscheidung.

## Ergebnisse des Replays

| Datei | Gespeichert | Korrektur | Aktueller Replay | Beobachtung |
| --- | --- | --- | --- | --- |
| korrektur | D19 | D3 | D3 | Lokale Detailverfeinerung behebt den Segmentfehler. |
| korrektur_1 | T14 | T20 | T14 | Alte gedrehte Kalibrierung. Dieser Replay kalibriert nicht neu; die separate Rotationsregression bleibt grün. |
| korrektur2 | T3 | 3 | T3 | Größerer radialer Fehler bleibt offen. |
| korrektur3 | T20 | 20 | T20 | Ringentscheidung bleibt offen. |
| korrektur4 | 20 | MISS | 20 | Möglicher Robin Hood, keine sichere Klassifikation aus den Bildern. |
| korrektur5 | 17 | T17 | 17 | Ringgrenze, Fehler bleibt offen. |
| korrektur6 | D16 | D7 | D16 | Segmentfehler bleibt offen. |
| korrektur7 | D16 | D7 | D16 | Duplikat von Nummer 6. |
| korrektur8 | T1 | T1 | T1 | Score stimmt, Position wurde korrigiert. |
| korrektur9 | 20 | T20 | 20 | Ringgrenze, Fehler bleibt offen. |
| korrektur10 | MISS | 5 | MISS | Stark abweichende Achsen/Position bleiben offen. |
| korrektur11 | MISS | D10 | MISS | Außenringentscheidung bleibt offen. |
| korrektur12 | T20 | 20 | T20 | Ringentscheidung bleibt offen. |

Nummer 4 hat einen Achsenwiderspruch von ungefähr 20 mm. Das passt zu einer
Spitze oberhalb der Board-Ebene, beweist aber keinen Robin Hood: falsche Achsen,
bewegte Flights oder eine ungenaue Kalibrierung können ebenfalls widersprechen.
Darum wird daraus keine automatische Robin-Hood-Regel abgeleitet. Der Fehler
bleibt ausdrücklich offen; eine sichere Lösung braucht zusätzlich eine Prüfung
des tatsächlichen Kontakts zur Boardfläche beziehungsweise des alten Darts.

## Übernommene Änderungen

- Verbundene Änderungs-Pixel werden einmal pro Frame, Referenz und Kalibrierung
  projiziert und für weitere Schaft- und Alternativsuchen wiederverwendet.
  Das aktuelle Bild ist ein schwacher Cache-Schlüssel, die Referenz ebenfalls
  schwach gespeichert. Neue Referenzen oder Kalibrierungen invalidieren den Cache.
- Die Detailverfeinerung betrachtet 35 statt 80 mm um den vorläufigen Treffer.
  Eine Korrektur bis 12 mm benötigt drei Ansichten und eine verbesserte
  Achsenübereinstimmung; sonst bleiben maximal 3 mm erlaubt.
- Bei sichtbarem Dart oder laufender Entscheidung beträgt die zusätzliche
  Aufnahmepause 20 statt 80 ms. Die serielle Fotoaufnahme bleibt erhalten.
  Die vorhandene begrenzte Entscheidung und das Herauszieh-Verhalten bleiben
  durch Regressionstests abgesichert.
- Diagnoseformat Version 6 ergänzt Aufnahme-/Dekodierzeit, Verarbeitungszeit
  und nächste Aufnahmepause unter `hit.performance`. Ältere Berichte bleiben
  durch die bisherigen toleranten Reader lesbar; für das zusätzliche optionale
  Messfeld ist keine Umschreibung alter Dateien nötig. Die Verarbeitungszeit
  ist bei einem Export aus dem Treffer-Callback die Zeit bis zu diesem Callback.

## Geschwindigkeitsmessung

Pro Fall wurden Schaft- und Alternativsuchen aller drei Kameras mit frischen
Frame-Objekten jeweils dreimal gemessen. Gleiche Parameter und Pixel mit und
ohne Wiederverwendung ergaben eine mediane Zeitreduktion von **39,8 %**,
im Mittel **40,3 %**. Das ist ein Benchmark der Bildauswertung im Flutter-Test,
keine End-to-End-Messung an angeschlossenen USB-Kameras und kein Vergleich
unterschiedlicher Hardware. Kameraaufnahme, Dekodierung und die zeitliche
Bestätigung gehören zusätzlich zur wahrgenommenen Latenz.

Rohdaten: `build/autoscore_analysis/october_replay.json`.
Positionsanalyse mit Deduplizierung:
`build/autoscore_analysis/october_position_analysis.json`.

Manueller Replay außerhalb der normalen Testmatrix:

```powershell
flutter test tool/autoscore_diagnostics_replay_test.dart
```

Andere entpackte Eingabedaten lassen sich über
`--dart-define=AUTOSCORE_DIAGNOSTICS_DIR=<Ordner>` auswählen. Dieser Replay
setzt die hier verwendeten Detail- und Sequenzdateien voraus.

## Ziel 99,5 Prozent

Das Ziel ist **noch nicht erreicht**. Ein geglätteter Score oder eine auf diese
Korrekturen angepasste Verschiebung würde die verbliebenen Ursachen verdecken.
Der sinnvolle nächste Ausbauschritt ist kontinuierliche, zeitlich abgeglichene
Kameraerfassung mit sichtbarer Spitze/Boardkontakt und überprüfter Kalibrierung.

Für eine belastbare Messung muss jeder reale Wurf unabhängig geprüft werden,
einschließlich fehlender Erkennungen, falscher Zusatzwürfe, Bouncer, Robin Hoods,
schwarzem Rand und eng stehenden Darts. Nicht korrigierte Würfe automatisch als
richtig zu verbuchen genügt dafür nicht. Testwürfe müssen von den zur Entwicklung
verwendeten Diagnosen getrennt sein. Bei unabhängigen Würfen ergeben 600
fehlerfreie Beobachtungen eine einseitige exakte 95-%-Untergrenze von ungefähr
99,502 % (`0.05^(1/600)`). Sobald Fehler auftreten, sind mehr Beobachtungen nötig.

## Validierung

91 Erkennungs-, Diagnose-, Rotations-, Bouncer- und Controller-Tests bestanden.
Zusätzlich wurden Kamerapanel, Demo, Hintergrundbetrieb und die neue
Detailregression geprüft. Reale USB-Latenz, neue Kameraaufnahmen sowie mobile
Geräte wurden in dieser Sitzung nicht geprüft; die Oberfläche wurde nicht geändert.
