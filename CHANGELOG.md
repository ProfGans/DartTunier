# Dart Turnier 0.1.8

Änderungen seit Version 0.1.7. Der Build trägt die interne Buildnummer 23
(Release-Tag `v0.1.8+23`).

## Spieler und Ranglisten

- Die zentrale Navigation wurde auf **Turniere**, **Spieler**, **Statistik**
  und **Ranglisten** ausgerichtet. Spieler werden zentral im Spielerkatalog
  gepflegt; dafür ist kein eigenes Konto pro Vereinsmitglied erforderlich.
- Ranglisten können unabhängig voneinander angelegt und mit Spielern aus dem
  Katalog besetzt werden. Spielerprofile zeigen ihre zugehörigen Ranglisten.
- Für klassische Elo-Ranglisten lassen sich Startwertung, New-, Normal- und
  Pro-Player-K-Faktoren sowie die Zahl der Partien bis zum Wechsel vom
  New-Player-Status einstellen.
- Zusätzlich gibt es Ranglisten im Serienformat mit Punkten für Teilnahme,
  gewonnene Sets, die Plätze eins bis drei und Bestleistungen. Ein Zeitraum
  kann die berücksichtigten Turniere eingrenzen.
- Turniere können einer oder mehreren Ranglisten zugeordnet werden. Bei
  Elo-Berechnungen zählen nur Begegnungen, bei denen beide Spieler Mitglieder
  der jeweiligen Rangliste sind; nicht zugewiesene Gäste verändern deren
  Wertung nicht.
- Ranglisten bieten einen Jahresrückblick mit Teilnahmen, Turniersiegen,
  gewonnenen und verlorenen Legs sowie Bestleistungen. Monatswerte und
  Gesamtwerte stehen für Auswertungen bereit.

## Turniere, Challonge und Bestleistungen

- Die Erstellung unterscheidet jetzt **Normales- oder Ranglistenturnier**
  sowie **Liga- oder Freundschaftsspiel**.
- Challonge-Turniere lassen sich in die lokale Turnierverwaltung importieren
  und exportieren. Importierte Challonge-Namen können optional mit lokalen
  Spielerprofilen verknüpft werden; mehrere Challonge-Aliase können einem
  Spieler zugeordnet und später im Spielerprofil gelöst werden.
- Importierte Turniere können nachträglich Ranglisten zugeordnet werden.
- Bei Ergebnissen lassen sich Bestleistungen erfassen und bearbeiten, auch
  nach Turnierabschluss und bei importierten Challonge-Partien: 170er,
  180er, High Finishes ab 100 und Shortlegs unter 19 Darts.
- Bestleistungen fließen in Spielerstatistiken und Serienranglisten ein.

## Statistik und Oberfläche

- Die Statistik ist in die Hauptnavigation umgezogen und wertet die lokalen
  Spielerprofile aus.
- Spielerstatistiken konzentrieren sich auf Siege, Niederlagen,
  Siegeschancen, Legs, Sets, Turnierteilnahmen und Bestleistungen. Aktivitäts-,
  Datenbasis- und Legqualitätsanzeigen aus dem früheren Statistikbereich
  entfallen.
- Turnierverwaltung, Spieler-, Statistik- und Ranglistenansichten wurden für
  die zentrale Vereinsverwaltung überarbeitet.
- Einstellungen bündeln Datensicherung und Cloud-Synchronisierung unter
  **Daten**.

## Konten, Datensicherung und entfernte Altbereiche

- Supabase synchronisiert den vollständigen lokalen Datenstand pro
  angemeldetem Betreiberkonto zwischen Geräten. Gleichzeitige Änderungen
  werden als Konflikt angezeigt; Upload oder Wiederherstellung eines ganzen
  Snapshots wird bewusst bestätigt.
- Ein anderes Supabase-Konto erhält einen getrennten Datenpool. Die
  Synchronisierung führt keine einzelnen Spieler oder Turniere automatisch
  zusammen.
- Community-Mitgliedschaften, Rollen, Einladungs-/QR-Beitritte,
  Community-Turniere, Geräte-Ergebnisweitergabe, Bot-Simulation, Scorer und
  automatisches Scoring wurden aus App-Navigation und Projekt entfernt.
- Die neue Supabase-Einrichtung verwendet das separate Projekt
  `pwqpcrzbmaxywcdotkbq`; die Release-Builds werden ausdrücklich mit dessen
  Projektadresse erzeugt.

## Installation

- **Android:** APK herunterladen und installieren. Für Updates muss die
  Installation mit demselben Android-Signierschlüssel erstellt worden sein.
- **Windows:** ZIP vollständig entpacken und
  `dart_tournament_manager.exe` aus dem entpackten Ordner starten.
- **Linux:** Das passende x64- oder ARM64-Archiv vollständig entpacken und die
  enthaltene Startdatei verwenden; die Laufzeit benötigt GTK 3 und GStreamer.

Vor dem Wechsel auf 0.1.8 empfiehlt sich ein Export der vorhandenen
App-Datensicherung. Der neue lokale Datenbankaufbau sichert eine erkannte alte
Datenbank vor der Umstellung als Backup-Datei.
