# Frisches Supabase-Backup

Jedes Supabase-Konto erhält einen getrennten privaten Komplett-Datenstand.
Spielerprofile selbst benötigen keine Supabase-Konten. Änderungen werden lokal
gespeichert und nach kurzer Verzögerung als vollständiger Datenstand
hochgeladen. Beim Start, nach Anmeldung und beim Fortsetzen der App wird ein
neuerer Cloud-Stand auf das Gerät geladen, sofern dort keine ungesicherten
lokalen Änderungen vorliegen. Laptop und Handy verwenden damit denselben Pool,
wenn beide mit demselben Supabase-Konto angemeldet sind. Andere Konten erhalten
eigene lokale und Cloud-Daten.

Wenn beide Geräte offline oder gleichzeitig Änderungen vorgenommen haben,
ersetzt die App keinen der beiden Stände automatisch. In **Einstellungen →
Daten** kann dann bewusst der lokale Stand hochgeladen oder der Cloud-Stand
geladen werden. Das ist eine Synchronisierung vollständiger Snapshots, keine
Zusammenführung einzelner Turniere oder Spieler.

## Einmalige Einrichtung

1. Im Supabase-Projekt `pwqpcrzbmaxywcdotkbq` unter **SQL Editor** den Inhalt von
   [`fresh_sync_schema.sql`](../supabase/fresh_sync_schema.sql) ausführen.
2. Unter **Authentication → Users** ein einziges Betreiberkonto anlegen und die
   E-Mail-Adresse bestätigen.
3. Den Publishable Key des neuen Projekts beim Flutter-Build setzen. Er ist ein
   öffentlicher Client-Key und darf nicht mit einem Secret-/Service-Role-Key
   verwechselt werden:

```powershell
flutter run `
  --dart-define="SUPABASE_URL=https://pwqpcrzbmaxywcdotkbq.supabase.co" `
  --dart-define="SUPABASE_PUBLISHABLE_KEY=<PUBLISHABLE_KEY_DES_PROJEKTS>"
```

Für Releases müssen dieselben `--dart-define`-Werte an den jeweiligen
`flutter build`-Befehl übergeben werden.

Die Backup-Richtlinien beschränken Lesen, Erstellen, Ersetzen und Löschen auf
den Ordner des angemeldeten Betreiberkontos. Es werden keine alten
Community-Tabellen oder Testdaten migriert. Der lokale Export und die
Wiederherstellung verwenden weiterhin die vorhandene Prüfsummen- und
Rollback-Logik. Die Cloud-Sicherung enthält Turniere, lokale Spielerkonten samt
Challonge-Verknüpfungen, Ranglisten, Bestleistungen und Planungseinstellungen.
Beim ersten Start mit dem neuen lokalen SQLite-Schema wird eine vorhandene
alte App-Datenbank vorher als `.bak` gesichert und auf Spieler, Ranglisten und
Challonge-Verknüpfungen reduziert. Deine bisher leere Spieler- und
Turnierdatenbank passt zu diesem Start.

### Release über GitHub Actions

Der Release-Workflow baut Android, Windows und Linux auf GitHub-Runnern; auf
dem eigenen Rechner sind dafür weder Android SDK noch NuGet erforderlich.
Die Projekt-URL und der Publishable Key des neuen Projekts sind im Workflow
hinterlegt. Der Publishable Key ist ein öffentlicher Client-Key. Die
Android-Signierung benötigt außerdem die vier Repository-Secrets
`ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_PASSWORD`
und `ANDROID_KEY_ALIAS`.

Nach dem Push auf `Trainingsbetrieb-DCUH` löst der Tag `v0.1.8+23` den Build
aus. Die GitHub-Action erstellt daraus das Release mit diesem Changelog.

Die Release-Notizen stammen aus der Datei [`CHANGELOG.md`](../CHANGELOG.md).
