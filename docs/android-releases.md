# Android-Updates über ProfGans/DartTunier

Die App verwendet das bestehende öffentliche Repository. Keine GitHub-Tokens werden in die APK eingebaut. Unter Einstellungen → Updates wird manuell nach veröffentlichten, stabilen Android-Releases gesucht.

## Einmalige Einrichtung

1. Der neue Release-Keystore wurde lokal unter `.secrets/android/release.jks` erstellt; die zugehörigen Werte liegen in `.secrets/android/github-secrets.json`. Diesen gesamten Ordner verschlüsselt außerhalb des Computers sichern. Paket-ID bleibt `de.dartturnierverwaltung.app`. Ohne denselben Signaturschlüssel sind spätere Updates nicht möglich. Keinen neuen Keystore für spätere Versionen erzeugen.
2. Unter GitHub → ProfGans/DartTunier → Settings → Secrets and variables → Actions diese Repository-Secrets hinterlegen:
   - `ANDROID_KEYSTORE_BASE64`: Base64-Inhalt des Keystores.
   - `ANDROID_STORE_PASSWORD`: Keystore-Passwort.
   - `ANDROID_KEY_PASSWORD`: Schlüssel-Passwort.
   - `ANDROID_KEY_ALIAS`: Alias des Schlüssels.
3. Für lokale Release-Builds `android/key.properties` erstellen mit `storeFile` (absoluter Pfad, unter Windows mit `/`), `storePassword`, `keyPassword`, `keyAlias`. Datei und Keystores sind git-ignoriert. Release-Builds verwenden niemals ersatzweise den Debug-Schlüssel.

Keystore und Passwörter nicht in Issues, Chat, Commits oder Release-Assets veröffentlichen.

Mit installierter und angemeldeter GitHub CLI lassen sich die vier Secrets über `tool/set_android_release_secrets.ps1` übertragen. Das Skript liest die lokalen Werte, übergibt sie über stdin und gibt sie nicht aus. Am 24.09.2026 wurden alle vier Secrets im Repository eingerichtet und eine geprüfte Schlüsselkopie im vom Besitzer bestimmten Backup-Ordner abgelegt. Die Cloud-Synchronisierung dieser Kopie muss separat kontrolliert werden.

Prüfstand 24.09.2026: Release `v1.0.0+2` ist unter https://github.com/ProfGans/DartTunier/releases/tag/v1.0.0%2B2 veröffentlicht. Die verwendete APK stammt aus dem erfolgreichen GitHub-Workflow https://github.com/ProfGans/DartTunier/actions/runs/36023666231. Der erste Build wurde nach Korrektur der Workflow-Konfiguration manuell gestartet; zukünftige Versionstags starten den korrigierten Workflow automatisch.

Die Signatur der GitHub-APK wurde mit `apksigner verify` bestätigt. Zertifikat-SHA256: `f14e4dfcfb69823a316db82558f484c0f4a49fd3a68bbf2a3f7e70a2127d884a`.

Im isolierten Android-Emulator (API 36) wurden Backup-Import und -Export über die echten Systemdialoge getestet. Anschließend wurde die GitHub-APK mit Buildnummer 2 ohne Deinstallation über eine ältere, gleich signierte Testversion mit Buildnummer 1 installiert. Die Vorher-/Nachher-Exporte haben für alle vier Speicher identische SHA256-Prüfsummen: `tournaments.json`, `app_database.sqlite`, `planning_settings.json`, `devices.json`. Das Testturnier einschließlich Ergebnis 2:1 blieb erhalten. Die Update-Seite erkennt anschließend Build 2 als aktuell. Ein physisches Android-Gerät und der komplette Download-/Installieren-Button-Ablauf wurden dabei nicht getestet; das APK-Upgrade erfolgte per ADB.

## Eine Version veröffentlichen

- `pubspec.yaml` erhöhen, z.B. `1.0.0+2`. Die Zahl nach `+` ist der Android-versionCode und muss mit jeder Veröffentlichung strikt steigen.
- Änderungen committen und pushen. Danach einen dazu passenden Tag `v1.0.0+2` pushen.
- GitHub Actions testet und baut die signierte Universal-APK sowie Windows-, Linux- und macOS-Pakete. Nach erfolgreichen Android- und Desktop-Jobs erstellt der Workflow **App Release** einen gemeinsamen **Release-Entwurf** mit `dart-turnier-android.apk`, den Desktop-Archiven und `SHA256SUMS`. Apple-Einschränkungen und Paketdetails stehen in `docs/desktop-and-ios-releases.md`.
- APK auf einem Testgerät prüfen und erst dann den Entwurf veröffentlichen. Die App ignoriert Entwürfe und Vorabversionen. Workflow-Dispatch baut nur ein herunterladbares Actions-Artefakt.
- Die App nutzt den von GitHub bereitgestellten SHA-256-Digest des APK-Assets. Ohne Digest wird kein installierbares Update angeboten. Tags ohne Buildnummer werden ebenfalls ignoriert.

## Installation und Datenerhalt

Die App lädt nur per HTTPS von GitHub und dessen Asset-Servern, prüft Länge und Prüfsumme und lässt Android Paket-ID, höhere Buildnummer und denselben Signaturschlüssel prüfen. Vor dem Start des Android-Installers wird eine lokale Sicherung erstellt. Fehlt die Freigabe zum Installieren aus dieser Quelle, öffnet die App Androids Einstellungen; anschließend erneut Installieren wählen.

Der Benutzer bestätigt die eigentliche Installation in Android. Nach Öffnen des Installers werden weitere lokale Speicherzugriffe gesperrt, bis die App neu gestartet wurde. Bestehende Benutzerdaten werden nicht gelöscht oder neu initialisiert.

**Erste Umstellung von Debug auf Release:** Android akzeptiert wegen der unterschiedlichen Signaturen kein direktes Update. Vor jeder Deinstallation muss ein externes Backup nachweislich vorliegen. Der Android-Export nutzt jetzt den systemeigenen Dokumentdialog (z.B. Downloads); Import verwendet die Datei-Auswahl. Zuerst eine mit dem bisherigen Debug-Schlüssel gebaute Zwischenversion mit dieser Backup-Funktion installieren und den Export auf dem Gerät prüfen. Erst danach gegebenenfalls Debug-App deinstallieren, Release-App installieren und externes Backup importieren. Keinesfalls ohne Sicherung deinstallieren.

Release-Prüfung: Workflow, signierte APK und In-place-Upgrade vor jeder weiteren Veröffentlichung kontrollieren. Der Workflow veröffentlicht absichtlich nicht selbständig.
