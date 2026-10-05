# Vergleich der vorhandenen Problemfälle nach dem Video-Ausbau

## Ergebnis

41 Diagnosepakete wurden durch denselben produktiven Controller abgespielt:
15 ältere Korrekturen, 6 aus Batch 2, 4 aus Batch 3, 3 aus Batch 4 und die
13 zuletzt gelieferten Pakete. Die letzten Nummern 6 und 7 sind dasselbe
Ereignis. Es bleiben 40 unterschiedliche Capture-Zeitpunkte.

Verglichen wurden die aktuelle Entscheidung ohne Übernahme der neuen
Spitzenschätzung und dieselbe Entscheidung mit aktiver Spitzenübernahme.
**In keinem Paket ändert sich der Score.** Der neue Ausbau weist auf diesen
gespeicherten Bildern daher keinen zusätzlichen Gewinn bei den Scores nach.
Es gibt auch keinen neuen Score-Rückschritt gegenüber diesem Vergleichspfad.
Die bereits zuvor behobene Verwechslung D19/D3 bleibt behoben.

Zusätzlich bestehen 77 gezielte Regressionstests zu gespeicherten Diagnosen,
Kalibrierung, Entscheidungslogik, automatischem Zählen,
Bouncern und Herausziehen. Einige Tests sichern ausdrücklich bekannte offene
Fehler ab. Ein grüner Testlauf bedeutet daher nicht 77 richtig erkannte Würfe.

## Letzte Diagnosepakete

| Paket | Benutzerkorrektur | Bisheriger Vergleichspfad | Neue Spitzenprüfung |
| --- | --- | --- | --- |
| korrektur | D3 | D3 | D3 |
| korrektur_1 | T20 | T14 | T14 |
| korrektur2 | 3 | T3 | T3 |
| korrektur3 | 20 | T20 | T20 |
| korrektur4, möglicher Robin Hood | MISS | 20 | 20 |
| korrektur5 | T17 | 17 | 17 |
| korrektur6 / korrektur7, Duplikat | D7 | D16 | D16 |
| korrektur8, Positionskorrektur | T1 | T1 | T1 |
| korrektur9 | T20 | 20 | 20 |
| korrektur10 | 5 | MISS | MISS |
| korrektur11 | D10 | MISS | MISS |
| korrektur12 | 20 | T20 | T20 |

Die alte gedrehte Kalibrierung in korrektur_1 wurde im Replay beibehalten.
Der Vergleich kann eine neue Live-Kalibrierung dieses Setups nicht ersetzen.

Gemessen an den gespeicherten manuellen Positionen verbessert die Spitzenprüfung
korrektur von 9,45 auf 7,41 mm Abstand und korrektur8 von 8,06 auf 7,22 mm.
korrektur2 verschlechtert sich von 32,22 auf 32,49 mm und der alte Rotationsfall
von 123,00 auf 123,87 mm. Sonstige Punkte bleiben unverändert. Diese Positionen
sind Benutzerangaben, keine unabhängig vermessene Wahrheit. Eine Bestätigung
von Schaftenden durch die Heuristik garantiert keinen tatsächlichen Boardkontakt.

## Weiterhin ausbleibende Erkennungen

case_43 und case_59 liefern in beiden Vergleichspfaden keinen Wurf. Die gemessene
Änderungsfläche zwischen den gespeicherten Vorher-/Trefferbildern beträgt nur
ungefähr 0,008 bis 0,021 Prozent je Kamera. Daraus entstehen keine brauchbaren
Kameraachsen. Weitere identische Bilder stellen die fehlende Wurfbewegung nicht
wieder her. Das belegt einen offenen Fall im gespeicherten Bildvergleich, nicht
den Ausgang eines neuen Versuchs mit kontinuierlicher Videoaufnahme.

## Grenzen dieser Prüfung

- Acht wiederholte gespeicherte Frames dienen zum Abspielen der Entscheidungslogik.
  Das sind keine acht unabhängig aufgenommenen Videoframes.
- Der EndpointReplayController aktiviert nur den neuen Algorithmuszweig. Er
  simuliert keine USB-Aufnahme, Belichtung, Hardware-Zeitabstände oder native Puffer.
- Für ältere Pakete wird das letzte Vorherbild bevorzugt; fehlt es, wird das
  gespeicherte Vorherbild verwendet. Fehlende Leerbilder fallen auf Vorher zurück.
  Diese Fälle prüfen die Trefferentscheidung, nicht das Herausziehen. Dafür
  wurden separat die bestehenden Tests mit echten Leer-/Belegt-Aufnahmen ausgeführt.
- Keine der letzten Aufnahmen liefert eine verwertbare räumliche Kontaktprüfung.
  Vollständige vorausgehende Wurfverläufe und unabhängige Kameraintrinsiken fehlen.
  Der Robin-Hood-Fall bleibt offen.
- Zeitabgleich, neue Kalibrierung am leeren Board, kurz sichtbare Abpraller und
  tatsächliche USB-Latenz benötigen neue Videoaufnahmen. Aus diesem Test lässt
  sich keine Beschleunigung an angeschlossenen Kameras ableiten.
- Dies sind ausgewählte Problem- und Entwicklungsfälle, keine unabhängige
  Genauigkeitsmessung. Das Ziel 99,5 Prozent ist weiterhin nicht nachgewiesen.

## Reproduzierbarkeit

Werkzeug: `tool/autoscore_diagnostics_replay_test.dart`.
`AUTOSCORE_DIAGNOSTICS_DIR` wählt den Eingabeordner,
`AUTOSCORE_REPLAY_ENDPOINTS=true` aktiviert die neue Spitzenübernahme und
`AUTOSCORE_REPLAY_OUTPUT` bestimmt den JSON-Ausgabepfad. Übergabe jeweils als
`--dart-define=NAME=WERT` an `flutter test`.

Rohdaten und Logs liegen unter `build/autoscore_analysis/`:
`all_problem_video_comparison.json`, `video_problem_comparison.json`,
`current_photo_replay.json`, `current_endpoint_replay.json`,
`problem_<batch>_<false|true>.json`, `problem_cases_validation.log`.
Die Auswertungslabels und Korrekturpunkte werden nicht an die Erkennung gegeben.

`flutter analyze` meldet ausschließlich den bestehenden Stilhinweis in
`test/manual_update_card_test.dart:35`. Die App-Logik wurde in dieser Prüfung
nicht geändert; es wurden das Replay-Werkzeug und dieser Bericht ergänzt.
