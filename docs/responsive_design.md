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

Die gespeicherte Einstellung „Übernahme bestätigen“, die Account-Geräteauswahl und der Bestätigungsdialog werden zusätzlich in `test/remote_settings_widget_test.dart` bei 360x800, 800x600 und 1440x900 mit 100/200 Prozent Schrift geprüft. Vorschauen: `remote_settings_*.png` und `remote_confirmation_*.png` unter `build/layout_previews/`. Netzwerkfälle und Persistenz stehen in `test/remote_account_control_test.dart`.

Fernsteuerung: `test/remote_control_widget_test.dart` prüft Kopplungsformular, Host-Freigabe, Live-Bedienansicht und Texteingabe bei 360x800, 800x600 und 1440x900 mit 100/200 Prozent Schrift. Die Live-Werkzeugleiste begrenzt ihre Höhe anhand der tatsächlich verfügbaren Layout-Höhe und bleibt scrollbar. Fensterwechsel erhalten Eingaben und verwerfen veraltete Remote-Koordinaten. Details und Grenzen: `docs/remote_control.md`.

Der standardmäßige Aktionsmodus verwendet die normalen Scorer-Widgets mit eigenem Layout auf dem Handy. `test/remote_scorer_widget_test.dart` prüft Host-Anbindung, manuelle Eingaben, Autoscoring-Anzeige, Eingabesperren und Verbindungsabbruch bei 360x800, 800x600 und 1440x900 mit 100/200 Prozent Schrift. Mit `LAYOUT_PREVIEW_FONT` entstehen `build/layout_previews/remote_native_360.png` und `remote_native_1440.png`.

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

Community-Statistiken: Der Bereich zeigt direkt das ausführliche Cockpit mit Kennzahlenvergleich und Form. Kompakte Aktionen öffnen die Spielerauswahl, Highlights und Trends. Spielerprofile zeigen das ausführliche Cockpit; der bisherige zusätzliche Einstieg und die alte Vergleichsseite entfallen. `test/community_statistics_navigation_test.dart` prüft den neuen Standard, Navigation, Zuordnung, leere Ergebnisse und Größenwechsel bei 360x800, 800x600 und 1440x900 mit 200 Prozent Schrift. Die Ansichten sind zusätzlich in der gemeinsamen Vorschau-Matrix enthalten.

Die Pruefung ersetzt keinen Durchlauf auf einem physischen Smartphone. Betriebssystem-Tastatur, Screenreader, Touch-Gesten und authentifizierte Online-Community-/Netzwerkzustaende wurden nicht vollstaendig auf realen Geraeten geprueft. Die Seitentests decken repraesentative Ausgangszustaende ab, nicht jede Kombination aus Turnierdaten, Dialog und Netzwerkzustand. Fuer neue Ansichten oder gefundene Sonderfaelle die Testmatrix gezielt erweitern.

Persönliches Profil: `test/personal_profile_test.dart` prüft den Editor bei 360x800, 800x600 und 1440x900 mit 100 und 200 Prozent Schriftgröße sowie kontogetrennte lokale Speicherung und Spotify-Linkvalidierung. Der Anzeigename im persönlichen Profil ist unabhängig vom Konto-Anmeldenamen. Profilbilder werden als verkleinerte PNG-Daten lokal und bei angemeldeten Online-Konten in Supabase gespeichert. Details: `docs/personal_profile.md`.




Erkennungs-Overlays des Autoscorers: `test/camera_recognition_view_test.dart` ergänzt die Matrix um echte Kameraaufnahmen und abgelehnte Bull-/Ring-Vorschläge, eine optionale Farbmaske sowie sichtbare Diagnosewerte bei 360x800, 800x600 und 1440x900 mit 100/200 Prozent Schrift. Gerenderte Desktop- und Mobile-Ansichten wurden geprüft.


Dart-Setup im persönlichen Profil: optionale Komponentenfelder in einer mobilen Spalte und mehreren Desktop-Spalten. Profiltests sichern Speicherung und Bedienung bei 360x800, 800x600, 1440x900 und 200 Prozent Schriftgröße ab. `test/dart_setup_widgets_test.dart` prüft den Erhalt von Eingaben beim Fenstergrößenwechsel; mit `--dart-define=LAYOUT_PREVIEW_FONT=C:/Windows/Fonts/segoeui.ttf` entstehen PNG-Vorschauen unter `build/layout_previews/dart_setup_*.png`. Mobile und Desktop-Vorschauen wurden am 03.10.2026 visuell geprüft. Eine Prüfung auf physischen Geräten steht noch aus.

Statistik-Cockpit: Spielerübersicht, Community-Vergleich und Kennzahlen-Detailseiten sind in der gemeinsamen Seitenmatrix enthalten. Zusätzlich prüft `test/statistics_analytics_widget_test.dart` sämtliche 40 Detailseiten mit Messwerten und ohne Daten bei großer Schrift. Mit der bisherigen `LAYOUT_PREVIEW_FONT`-Option werden Vorschauen des Cockpits, Community-Vergleichs und einer Detailseite erzeugt. Mobile und Desktop-Vorschauen wurden am 03.10.2026 visuell geprüft. Details zur Berechnung und Datenbasis stehen in `docs/statistics_analytics.md`.

Personalisierte Checkoutwege: `test/preferred_checkouts_widget_test.dart` prüft das Lieblingsdoppel und den Wechsel zur Standardanzeige beim Gegner bei 360x800, 800x600 und 1440x900 mit 200 Prozent Schrift. Die optionalen Vorschauen `preferred_checkout_360.png` und `preferred_checkout_1440.png` wurden visuell auf Umbruch und vollständige Wege geprüft. Keine Prüfung auf physischen Geräten.

Cockpit-Heatmap: `test/cockpit_heatmap_test.dart` prüft Zuordnung über Spiel-ID/Spielerposition, Zeitraum, Checkout-/Schätzfilter, Detailnavigation und Größenwechsel bei 360x800, 800x600 und 1440x900 mit 100/200 Prozent Schrift. Über `LAYOUT_PREVIEW_FONT` entstehen `cockpit_heatmap_<Breite>_<Skalierung>.png`. Mobile und Desktop wurden am 04.10.2026 visuell geprüft; physische Geräte wurden nicht geprüft. Die allgemeinen Cockpit-/Community-/Responsive-Tests bleiben zusätzlich verbindlich.

## Sportliches App-Design (04.10.2026)

Das gemeinsame Theme in `lib/app/app_theme.dart` definiert Petrol-/Gruenfarben, helle Inhaltsflaechen, Typografie sowie Karten, Eingaben, Aktionen, Dialoge und Tabellen fuer alle Features. Fachliche Farben von Dartboards, Heatmaps und Qualifikationsanzeigen bleiben erhalten.

`SportAppShell` ist eine eigenstaendige Library unter `lib/app/navigation/`. Die Hauptbereiche werden vom Dashboard mit gemeinsamer Bereichsnavigation geoeffnet. Ab 1100 Pixel und geeigneter Textgroesse erscheint die Seitenleiste; sonst liegt das Bereichsmenue oberhalb des Inhalts. Die Elementposition der Inhaltsseite bleibt beim Layoutwechsel gleich, damit Formulare ihren Zustand behalten. Unterseiten und Match-Arbeitsflaechen verwenden weiterhin ihre vorhandene Zuruecknavigation und das gemeinsame Theme.

Die Startseite zeigt direkte Aktionen fuer Turniererstellung und Scorer, vier Bereichskarten sowie Konto und aufklappbare Verwaltungswerkzeuge. Sportliche Bereichsueberschriften fuer Turniere, Spieler und Scorer liegen in `lib/shared/widgets/sport_page_heading.dart`; Dashboard-Bausteine in `lib/features/home/presentation/widgets/sport_dashboard.dart`.

Pruefungen: `flutter analyze` ohne Befunde. Gemeinsame adaptive und responsive Regressionen bei 100/200 Prozent Schrift bestanden; `test/sport_navigation_test.dart` prueft Navigation und Eingabeerhalt bei Fensterwechsel fuer 360x800, 800x600 und 1440x900. Turniermatrix mit 32 Szenarien und Scorer-Widgettests bestanden. Der Scorer-Test scrollt jetzt vor dem Bot-Einstieg zur Aktion und wartet auf die Scrollbewegung.

Gerenderte Desktop- und Mobile-Vorschauen der Startseite sowie Turnier- und Scoreransichten wurden visuell kontrolliert. Keine Pruefung auf einem physischen Smartphone; authentifizierte Netzwerkzustaende sind durch diese Designpruefung nicht vollstaendig abgedeckt.

## Aufgeraeumte Bereichsmenues (04.10.2026)

Die Bereichsmenues nutzen `lib/shared/widgets/sport_menu.dart`: kurze beschriftete Eintraege auf einer gemeinsamen Flaeche pro Aufgabengruppe, dezente Trennlinien und konsistente Icons. Die gesamte Zeile ist bedienbar. Verwaltung und Kamera-Werkzeuge sind aufklappbar; ihr Zustand bleibt beim Fenstergroessenwechsel erhalten. Zusatzaktionen liegen in beschrifteten Popup-Menues, deaktivierte Aktionen bleiben deaktiviert.

Umgestellte Einstiege: Spielzentrale, Scorer (Spielen / Training & Analyse / Kamera & Erkennung), Community (Spieltag / Team & Leistung / Community verwalten), Turniererstellung und Kopplungsaktionen. Doppelte Geraete-/Einstellungslinks im Dashboard-Werkzeugkasten sind entfernt. Die Startseiten-Kopfflaeche ist kuerzer. Bereits ausgewaehlte Hauptbereiche erzeugen beim erneuten Anklicken keine weitere Route.

`lib/shared/widgets/sport_section_navigation.dart` vereinheitlicht die Bereichsauswahl fuer Einstellungen und Turnieransichten. Auf Desktop erscheinen beschriftete Auswahlchips, bei wenig Platz oder grosser Schrift eine Auswahlliste. Die Einstellungen haben keine zusaetzliche Seitenleiste mehr. Die Turnieretappen nutzen auf kleinen Displays ebenfalls eine Auswahlliste statt horizontalem Navigationsscrollen. Im Turniermenue liegen Highlights, Board-Zuordnung und Rueckkehr zum Hauptmenue; die feste Kopfzeile enthaelt keinen separaten Highlight-Button mehr.

Die gemeinsamen Popup- und Aufklappmenue-Styles gelten auch fuer bestehende Kontextmenues. Turnierregeln, Account-Berechtigungen und Persistenz sind unveraendert.

Validierung: 62 Tests aus 13 Suites bestanden, einschliesslich kompletter Community-Menue-Zugaenge, Erhalt aufgeklappter Menues beim Groessenwechsel, deaktivierter Zusatzaktionen, Turniererstellung, Scorer-/Wizard-Navigation, Geraeteseite, Order of Play, adaptiver Seitenmatrix und Turniermatrix. `flutter analyze` ohne Befunde. Vorschauen fuer Startseite, Scorer, Einstellungen und Community-Menue wurden auf Desktop und Mobile visuell kontrolliert. Physische Smartphones und authentifizierte Online-Zustaende wurden nicht vollstaendig geprueft.

## Weitere Menues vereinheitlicht (04.10.2026)

Kontoaktionen, persoenliche Profilverwaltung, Profil-Scorer-Einstieg, Community-Auswertungen, Ranglistenauswahl, Ergebniseinstiege, Backup-Aktionen sowie Push-Sender und Push-Empfang nutzen nun die gemeinsamen SportMenuGroup-Eintraege. Statusinformationen und Berechtigungen bleiben erhalten; beim Anmelden bleibt insbesondere der Hinweis auf Online-Konto oder lokalen Gastmodus sichtbar.

Das Statistik-Cockpit nutzt SportSectionNavigation fuer Scorer-/Turnierergebnisse und Einzel-/Doppelauswahl. Kleine Displays erhalten kompakte Auswahllisten; breite Fenster beschriftete Auswahlchips. Zeitraumfilter bleiben direkt bedienbare Filter, keine weitere Navigationsebene.

SportMenuLabel vereinheitlicht Kontextmenues mit Icons und umbrechenden Beschriftungen fuer Spieler, Team-Zusammenstellung, Community-Mitglieder, Ranglistenaktionen, Turnieraktionen, Highlight-Verwaltung und Order of Play. Vorhandene PopupMenuButton-Typen, Werte, Berechtigungspruefungen und Bestaetigungsdialoge sind erhalten. Deaktivierte Eintraege in SportMenuGroup sind auch visuell deaktiviert.

Validierung: 106 Tests aus 19 Suites bestanden, einschliesslich gemeinsamer Responsive-Matrix, Profil, Statistik, Backup, Push, Ranglisten, Highlights, Teams, Ergebnisse, Order of Play und Turniermatrix. Registrierung und Abmeldung im umgestalteten Kontomenue separat bestanden. Ein aelterer Scorer-Test wurde auf Scrollen zur Rueckgaengig-Aktion und den bereits vorhandenen Zwischenspeichern-Dialog angepasst; SharedPreferences sind im Test isoliert. Keine Aenderung der Scorer-Fachlogik.

flutter analyze ohne Befunde. Gerenderte Desktop-/Mobile-Ansichten von Profil, Ergebnissen und Community-Auswertungen wurden kontrolliert. Physische Smartphones, Linux-Benachrichtigungsdienst und authentifizierte Online-Zustaende wurden nicht auf echten Geraeten geprueft.


## Turnierbetrieb und Scorer auf Mobile (05.10.2026)

Der X01-Scorer zeigt Restpunkte in eigenen Sport-Panels mit hervorgehobenem aktiven Spieler. Auf schmalen Displays nutzt die Punkteingabe drei breite Ziffernspalten; Schnellwerte bleiben separat erreichbar. Bei grosser Schrift wachsen die Elemente und Spieler-Panels wechseln auf eine Spalte. Statistik und Kamera bleiben direkt in der Kopfzeile erreichbar; doppelte Aktionen oberhalb der Tastatur wurden entfernt. Checkout-Hinweise erscheinen im Finish-Bereich. Die Keypad-Instanz und bereits eingegebene Ziffern bleiben beim Wechsel zwischen Mobile und Desktop erhalten.

Die Turnierliste nutzt responsive Status-Karten mit eigenem Aktionsmenue. Kopfbereich, Etappenauswahl, Spiele und Abschlussaktionen im Turnierbetrieb liegen in einer gemeinsamen scrollbaren Flaeche. Mobile Match-Karten trennen Spielernamen und Ergebnisaktionen. Scorer-Einstellungen haben einen eigenen Formularabschnitt. Keine Aenderung an Turnierregeln oder Speicherschema.

Validierung: flutter analyze ohne Befunde; 65 Tests aus 14 Suites einschliesslich Turniermatrix, Scorer-Abschluss/Rueckgaengig, Bots, Doppel, Kamera und Fernsteuerung bestanden. Nach abschliessender Layout-Anpassung 19 Responsive-/Scorer-Tests erneut bestanden. Die Seitenmatrix enthaelt nun die echte TournamentRunPage und prueft auch aufgeklappte Spiele und Scrollen zu Abschlussaktionen. Groessen: 360x800, 800x600, 1440x900 bei 100 und 200 Prozent Schrift; Eingabe-Zustand und Touch-Ziele zusaetzlich bei 320x568 und Fensterwechsel geprueft. Gerenderte Scorer-/Turnieransichten auf Desktop und Mobile visuell kontrolliert. Physische Smartphones und echte Kamera-/Netzwerk-Verbindungen wurden in dieser Designpruefung nicht getestet.


## Mobile Gruppenuebersicht vereinfacht (05.10.2026)

Auf schmalen Gruppenflaechen stehen offene Spiele direkt sichtbar vor der Tabelle. Tabellen/Qualifikation und abgeschlossene Spiele sind getrennte aufklappbare Bereiche. Bei mehreren Gruppen zeigt die mobile Etappenuebersicht eine Gruppenauswahl und nur die ausgewaehlte Gruppe; breite Fenster behalten die Gesamtuebersicht. Gruppenverwaltung ist eingeklappt, eine Etappenauswahl fuer nur eine Etappe entfaellt. Die bestehende Ergebnisbearbeitung und Berechnung bleiben erhalten.

Validierung: flutter analyze ohne Befunde; 18 Tests aus Responsive-, Order-of-Play- und Turniermatrix-Suites sowie ein neuer Gruppen-Test bestanden. Der Gruppen-Test prueft Auswahl-Erhalt bei Mobile/Desktop-Wechsel und aufklappbare abgeschlossene Ergebnisse. Seiten bei 360x800, 800x600 und 1440x900 mit 100/200 Prozent Schrift geprueft. Gerenderte mobile und Desktop-Turnieransichten visuell kontrolliert; keine Sichtpruefung auf physischen Smartphones.
