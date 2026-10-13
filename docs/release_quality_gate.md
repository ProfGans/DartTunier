# Release- und Plattformprüfungen

Stand: 2026-10-13. Der CI-Einstieg für App-Releases ist
`.github/workflows/android-release.yml`.

## Automatisierte Prüfungen

- Vollständige Flutter-Analyse läuft mit `--no-fatal-infos`, weil ein
  bestehender Info-Lint im ausdrücklich ausgeklammerten Remote-Scorer liegt.
- Ein zweiter, strenger Analyseaufruf deckt `features/home`,
  `features/tournaments` und die Turnier-Simulation/-Listen-Tests ab.
- Der Releasegate führt Turnierlisten-/Löschdialog-, Simulations-,
  Turnierleitungs-/Rechte-, Backup-/Restore-, Round-Robin-Migrations- und
  adaptive Layouttests aus.
- Turnierseiten zeigen den aktuellen lokalen Synchronisations- oder
  Konfliktstatus an; Konflikthinweise sind als Live-Region ausgezeichnet.
- CI baut Android APK, Windows x64 sowie Linux x64 und ARM64. Linux-Releases
  prüfen zusätzlich die ELF-Architektur der erzeugten Binärdateien.

## Speicherstände

Der Turnier-JSON-Speicher steht auf Schema 22; die Versionschronik und die
Altbestandsbehandlung sind in
[`tournament_storage_schema.md`](tournament_storage_schema.md) dokumentiert.
Die lokale SQLite-Datenbank steht auf Version 5. Backupprüfung validiert
Turnier-JSON, Geräteeinstellungen und SQLite-Konsistenz sowie vorhandene
Migrationen auf isolierten Kopien.
Das versionierte Dateiinventar samt Grenzen steht in
[`backup_manifest.md`](backup_manifest.md).

## Manuelle Abnahme

CI-Builds belegen Kompilierbarkeit, nicht die Installation oder ein Upgrade auf
realen Geräten. Vor einer Veröffentlichung bleiben Geräteinstallation,
Upgrade mit echten Altständen und Wiederherstellung einer konkreten Sicherung
manuell abzunehmen. Hardwareabhängige Prüfungen werden hier nicht als CI-Erfolg
ausgegeben.
