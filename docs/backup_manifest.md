# Lokales Backupmanifest

Stand: 2026-10-13. Das Backupformat von `BackupService` ist Version 1 und
verwendet eine feste Dateiliste. Ein Eintrag enthält entweder `null` für eine
Datei, die auf dem Gerät noch nicht angelegt wurde, oder Base64-Daten mit
SHA-256-Prüfsumme. Restore prüft alle Einträge und migriert Datenbankkopien
isoliert, bevor Live-Dateien ersetzt werden.

| Datei | Inhalt | Eigene Version |
| --- | --- | --- |
| `tournaments.json` | Lokale Turniere, Ergebnisse, Rechte-/Outboxdaten und Turniercaches | JSON-Schema 22 |
| `app_database.sqlite` | Lokales Konto und Spielerprofile | SQLite user_version 5 |
| `planning_settings.json` | Dauerannahmen des Turnierformat-Finders | JSON-Schema 2 |
| `devices.json` | Gekoppelte Geräte und Verbindungseinstellungen | JSON-Schema 2 |

Zugangstokens und Authentifizierungsgeheimnisse werden nicht in das Backup
aufgenommen. Die Dateiliste ist absichtlich eine Allowlist, damit ein Backup
keine beliebigen Pfade überschreiben kann.

Die vier registrierten Dateien sind der aktuelle Vertrag, keine vollständige
Erfassung jedes App-Preferences-/Feature-Speichers. Weitere Turnierverwaltungs-
Speicher müssen vor einer Erweiterung des Manifests inventarisiert und mit
Altversions-/Teilfehler-Restoretests abgesichert werden. Scorer- und
Autoscoring-Drafts bleiben außerhalb dieses Turnierverwaltungs-Backups.
