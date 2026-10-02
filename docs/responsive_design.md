# Desktop- und Mobile-Design

Stand: 30.09.2026. Die Vorgaben in `AGENTS.md` gelten fuer alle weiteren UI-Aenderungen.

## Gemeinsame Layouts

`AdaptiveContentList` begrenzt Formular- und Listenansichten auf 1120 logische Pixel, zentriert sie auf Desktop und reduziert seitliche Raender unter 600 Pixel auf maximal 16 Pixel. SafeArea und Scrollen bei eingeblendeter Tastatur sind beruecksichtigt. Brackets und andere raeumliche Arbeitsflaechen behalten ihre eigene Breitensteuerung.

`AdaptiveTileLayout` verteilt Kacheln auf ein bis drei Spalten. Die Mindestbreite richtet sich auch nach der Schriftgroesse. Kacheln haben keine feste Hoehe.

## Pruefung und Verbesserungen

| Bereich | Ergebnis |
| --- | --- |
| Hauptmenue | Mehrspaltige Bereichskacheln auf Desktop; eine Spalte auf Mobile. |
| Autoscore-Tester | Direkte Kamerademo mit Punktestand und scrollbar gehaltenem Verlauf automatisch gezählter Treffer. Menü, automatische Trefferübergabe und Zurücksetzen sowie 360x800, 800x600 und 1440x900 mit 100 und 200 Prozent Schrift sind in `test/autoscore_demo_test.dart` geprüft; die Seite ist zusätzlich in der gemeinsamen Matrix enthalten. |
| Turnierliste, Spieler, Community, Geraete, Dev Tools | Gemeinsame lesbare Inhaltsbreite und mobile Abstaende. |
| Einstellungen, Backups, Updates, Bots | Seitennavigation ab 840 Pixel; kompakte Bereichsauswahl bei kleinen Fenstern oder grosser Schrift. Eingaben bleiben beim Layoutwechsel erhalten. |
| Turniererstellung | Auswahlfelder passen sich der Breite an; lange Texte koennen umbrechen. Formularzeilen beruecksichtigen Schriftvergroesserung. Tie-Breaker-Texte bleiben innerhalb der Flaeche und haben groessere Pfeiltasten. |
| Turnierdurchfuehrung | Kompakte Ansichtsauswahl auf Mobile, beschriftete Segmente auf Desktop. Ansichts-/Etappenwechsel beginnt mit passender neuer Scrollposition. Hauptmenue-Aktion als Icon mit Tooltip. |
| Ergebnisse | Podiumskarten passen ihre Spaltenzahl an Platz und Schriftgroesse an; Spielernamen werden nicht auf zwei Zeilen abgeschnitten. |
| Scorer und Checkout | Lesbare Formularbreite, korrigierte Auswahlfelder bei grosser Schrift. Bestehende zweispaltige Matchansicht und Tastatureingabe bleiben erhalten. |
| Autoscorer | Drei Kamera-Kacheln auf Desktop, gestapelte Ansichten bei wenig Platz. Automatische Kalibrierung mit kamerabezogenen Hinweisen und erkannten Referenzpunkten; Korrekturformular scrollbar. Separate Tests für 360x800, 800x600 und 1440x900 mit 100 und 200 Prozent Schriftgröße. |
| Brackets, Tabellen, Board-Anzeige | Bestehende fachliche Darstellung beibehalten; keine globale Breitenbegrenzung fuer Brackets oder Board-Anzeige eingefuehrt. |

## Wiederholbare Pruefungen

```powershell
flutter analyze
flutter test test/adaptive_layout_test.dart test/responsive_pages_test.dart
flutter test test/tournament_simulation_matrix_test.dart
```

Die Baustein-Tests decken 320x568, 360x800, 800x600 und 1440x900 mit 100 und 200 Prozent Schriftgroesse ab. Seitentests pruefen 360, 800 und 1440 Pixel Breite bei 800 Pixel Hoehe, scrollen durch die Inhalte und testen den Erhalt ungespeicherter Einstellungen beim Fensterwechsel. Sie verwenden einen temporaeren Speicherordner.

Fuer gerenderte Vorschauen mit einer lokal vorhandenen Schrift:

```powershell
flutter test test/responsive_pages_test.dart --dart-define=LAYOUT_PREVIEW_FONT=C:/Windows/Fonts/segoeui.ttf
```

Die PNGs liegen unter `build/layout_previews/`. Dies ist eine optionale Sichtpruefung; die normalen Tests benoetigen keine Windows-Schriftdatei. Die Vorschauen verwenden das App-Theme und Material-Icons.

Abschlusspruefung: `flutter analyze` ohne Befunde; 45 Tests aus elf betroffenen Testsuiten bestanden, einschliesslich Turniermatrix, Scorer, Geraeten, Backups, Etappenformaten, Platzierungen und Order of Play. Gerenderte Hauptmenue-, Einstellungs-, Scorer- und Ergebnisansichten wurden visuell kontrolliert.

## Grenzen der Pruefung

Die Pruefung ersetzt keinen Durchlauf auf einem physischen Smartphone. Betriebssystem-Tastatur, Screenreader, Touch-Gesten und authentifizierte Online-Community-/Netzwerkzustaende wurden nicht vollstaendig auf realen Geraeten geprueft. Die Seitentests decken repraesentative Ausgangszustaende ab, nicht jede Kombination aus Turnierdaten, Dialog und Netzwerkzustand. Fuer neue Ansichten oder gefundene Sonderfaelle die Testmatrix gezielt erweitern.

Persönliches Profil: `test/personal_profile_test.dart` prüft den Editor bei 360x800, 800x600 und 1440x900 mit 100 und 200 Prozent Schriftgröße sowie kontogetrennte lokale Speicherung und Spotify-Linkvalidierung. Der Anzeigename im persönlichen Profil ist unabhängig vom Konto-Anmeldenamen. Profilbilder werden als verkleinerte PNG-Daten lokal und bei angemeldeten Online-Konten in Supabase gespeichert. Details: `docs/personal_profile.md`.




Erkennungs-Overlays des Autoscorers: `test/camera_recognition_view_test.dart` ergänzt die Matrix um echte Kameraaufnahmen und abgelehnte Bull-/Ring-Vorschläge, eine optionale Farbmaske sowie sichtbare Diagnosewerte bei 360x800, 800x600 und 1440x900 mit 100/200 Prozent Schrift. Gerenderte Desktop- und Mobile-Ansichten wurden geprüft.

