# Performance-Optimierungen und Messung

Stand: 07.10.2026. Keine FPS-Zusage für Windows, Steam Deck oder Raspberry Pi:
die Messwerte unten stammen aus einem synthetischen Flutter-Test unter Windows.

## Änderungen

- Statistikberichte sind unveränderliche Snapshots. Spieler werden einmal
  gruppiert; Gesamtwerte, Messreihen und kumulierte Reihen werden je Bericht und
  Kennzahl wiederverwendet. Der zuletzt verwendete Zeitraum-/Spielfilter bleibt
  zwischengespeichert. Neue Berichte nach Ergebniskorrekturen erhalten neue Caches.
- Kumulierte Diagramme berechnen ihre Präfixe in einem Durchlauf. Spielerlisten,
  Gegneranalyse und Einzelwerte bauen höchstens 40 Einträge pro Seite auf.
- SQLite-Schema 4 speichert Heatmaps pro Sitzung in `heatmap_sessions`.
  Speichern ersetzt ausschließlich die betroffene Sitzung; wartende Änderungen
  derselben Sitzung werden zusammengefasst. Unveränderte Inhalte erzeugen kein
  UPDATE. JSON-Konvertierung erfolgt außerhalb des UI-Isolates.
- Das SharedPreferences-Archiv `scorer_heatmap_archive_v1` wird einmalig und
  transaktional übernommen. Ungültige Archive bleiben ohne Teilimport retrybar.
  Das Original bleibt in SharedPreferences und als `legacy_json` erhalten.
  Ein Migrationsmarker verhindert, dass gelöschte Sitzungen erneut erscheinen.
  Die bestehende Datenbankmigration sichert Version 3 vor dem Upgrade. Heatmaps
  werden anschließend durch die vorhandene Datenbanksicherung mitgesichert.
  Ältere Apps können Schema 4 nicht öffnen; kein Downgrade mit dieser Datenbank.
- Große Turnier-JSONs (ab 256 KiB Zeichenlänge) werden im Hintergrund dekodiert;
  das Kodieren beim Schreiben läuft ebenfalls dort. Dateiformat, Backup und
  atomarer Austausch bleiben erhalten. Die Datei wird weiterhin vollständig
  geschrieben; eine neue Turnierdatenbank ist nicht Teil dieser Änderung.
- Der Turnierformfinder läuft in einem eigenen Isolate. Abbruch, Schließen des
  Dialogs und Änderung der Texteingaben beenden eine laufende Berechnung.
- Der Live-Autoscorer verwendet einen wiederverwendeten Worker für Bildvergleich,
  primäre Schaftachse und Änderungspixel aller drei Kameras. Es gibt höchstens
  einen laufenden Auftrag. Ergebnisse nach Stop/Reset/Kalibrierungswechsel werden
  verworfen. Die bestehende Video-Pufferbegrenzung bleibt erhalten. Zeitabhängige
  Trefferentscheidung, alternative Achsen, Kontaktverfeinerung und UI-Callbacks
  laufen weiterhin im Controller. Ihre vollständige Auslagerung ist eine weitere
  Optimierungsstufe und muss anhand echter Profile bewertet werden.

## Reproduzierbarer Statistik-Benchmark

```sh
flutter test --no-pub tool/performance_statistics_test.dart
```

100 Spieler, synthetische Beobachtungen, sieben Wiederholungen; die ersten zwei
sind Warm-up. Gemessen werden Berichterstellung, Spielerfilterung, Sortierung,
eine Kennzahl, Messreihe und Form. Median der übrigen fünf Durchläufe:

| Beobachtungen | Vorher (ms) | Nachher (ms) |
| --- | ---: | ---: |
| 1.000 | 2,688 | 2,390 |
| 10.000 | 23,820 | 4,764 |
| 50.000 | 132,604 | 50,472 |

Identische Kontrollsummen. Keine Rendering-/Netzwerk-/Startzeitmessung, kein
Release-Benchmark. Laufzeit und Speicher hängen von Rechner und Daten ab.

## Geräteprofiling

Auf einem Entwicklungsrechner mit Flutter und dem passenden Plattform-SDK:

```sh
flutter run --profile -d windows --dart-define=PERFORMANCE_LOG=true
# Auf dem Linux-x64-Gerät (Steam Deck im Desktop-Modus):
flutter run --profile -d linux --dart-define=PERFORMANCE_LOG=true
```

Ohne diesen Schalter ist die Diagnose inaktiv. `PERF`-Zeilen enthalten Zeit bis
zur ersten Frame-Rückmeldung ab Bootstrap sowie alle zehn Sekunden Anzahl Frames,
Build-/Raster-P95, Anzahl Frames über 16,67 ms und Prozess-RSS in MiB. Die
16,67-ms-Grenze ist eine feste 60-Hz-Referenz, keine automatische FPS-Messung.
Die erste Frame-Rückmeldung enthält auch Callback-Verzögerung und bedeutet nicht,
dass sämtliche Online-Daten geladen sind. RSS ist Prozessspeicher, nicht Dart-Heap.
Es werden keine Spielernamen, Trefferbilder oder Accountdaten protokolliert.

Für einen Vergleich jeweils gleiche Datenkopie, Fenstergröße, Bildwiederholrate,
Stromversorgung und Kameraeinstellungen verwenden. Drei Durchläufe messen:

1. Kaltstart bis zur benutzbaren Startseite, danach 30 Sekunden Leerlauf.
2. Großes Statistikarchiv öffnen, Filter wechseln, Verlauf und Seiten wechseln.
3. Turnier mit 32/64/128 Spielern planen, laufende Suche abbrechen.
4. Drei Kameras mindestens zwei Minuten betreiben, Würfe und Herausziehen prüfen.
5. Fernsteuerung zusätzlich verbinden; Aktionsmodus und Spiegelung getrennt messen.

In Flutter DevTools zusätzlich UI-/Raster-Timeline und Heap vor/nach dem Ablauf
aufzeichnen. Kamera-Latenz anhand echter Würfe prüfen; synthetische Replaytests
messen weder USB-Latenz noch Zuverlässigkeit auf dem Zielgerät.

## Regressionen

`test/performance_regressions_test.dart` prüft Worker-Lebenszyklus, Überlastschutz,
Abbruch, identische Kameraanalyse, Statistik-Präfixe, Pagination, SQLite-Backup,
transaktionale Altarchivmigration und zusammengefasste Speicheranforderungen.
Bestehende Statistik-, Backup-, Kamera-, Planungs-, Turniermatrix- und responsive
Tests bleiben maßgeblich. Physische Steam-Deck-/Pi-/Mobilgerätetests stehen aus.

Validierung unter Windows: `flutter analyze --no-pub` ohne Befund; Statistik-,
Backup-, Kamera-, Planungs-, Turniermatrix- und responsive Tests erfolgreich.
Die zwölf Performance-Regressionstests einschließlich sofortigem Worker-Abbruch
und Pagination bei 360×800, 800×600 und 1440×900 mit 200 Prozent Schrift bestehen.
Mobile und Desktop-Statistikvorschauen wurden zusätzlich visuell geprüft.
Ein Windows-Profilbuild mit aktiviertem Diagnose-Schalter wurde erfolgreich gebaut.
