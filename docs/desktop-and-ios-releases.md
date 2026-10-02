# Releases für weitere Plattformen

Der Workflow `.github/workflows/android-release.yml` heißt nun **App Release**.
Ein neuer Tag passend zu `pubspec.yaml` baut Android, Windows und Linux.
Erst nach erfolgreichen Android-Prüfungen und allen Desktop-Builds wird ein
gemeinsamer Release-Entwurf mit SHA256SUMS angelegt. Manuelle Workflow-Starts
erzeugen ausschließlich Actions-Artefakte. Bestehende Releases werden nicht verändert.

- Windows: x64 ZIP mit EXE, DLLs und Datenverzeichnis. Vollständig entpacken.
  Noch keine Authenticode-Signatur. Eventuell benötigt der Rechner die Microsoft
  Visual C++ Redistributable x64 Laufzeit.
- Linux: x64 tar.gz, gebaut auf Ubuntu 22.04. GTK 3 und kompatible Systembibliotheken
  erforderlich; kein universelles Paket für alle Distributionen.
- macOS und iOS: Builds und Release-Pakete sind vorerst deaktiviert. Die Plattform-
  Projekte bleiben für eine spätere Wiederaufnahme erhalten. Für TestFlight/App Store
  müssen Apple-Developer-Mitgliedschaft, registrierte Bundle-ID, Signierungszertifikat,
  Provisioning und App-Store-Connect-Zugang eingerichtet werden. Diese Daten gehören
  ausschließlich in GitHub Secrets, niemals in das Repository.

Für macOS ist als nächster Schritt Developer-ID-Signierung plus Notarisierung nötig.
Die bestehenden Bundle-IDs bleiben bis zur abgestimmten Apple-Einrichtung unverändert,
damit sich bisherige Speicherorte nicht durch Umbenennung ändern.

Desktop-Pakete ersetzen keine Benutzerdaten und enthalten keine lokalen Speicherstände.
Vor dem manuellen App-Wechsel Backup exportieren und App schließen. Die automatische
Update-Suche innerhalb der App unterstützt Android, Windows x64 und Linux x64,
einschließlich optionaler GitHub-Vorabversionen. Desktop-Updates werden nach Klick
auf „Update installieren und neu starten“ heruntergeladen, geprüft, mit interner
Datensicherung installiert und gestartet. Es gibt keine unbeaufsichtigte Installation.

Windows- und Linux-Pakete enthalten ab diesem Workflow-Stand eine versionierte
`data/update-manifest.json`. Ältere Pakete ohne diese Datei müssen manuell installiert
werden. Auch die erste App-Version mit Desktop-Updater muss einmal manuell installiert
werden; danach kann sie neuere veröffentlichte Releases selbst installieren.

Neue Versionen liegen im App-Datenordner unter `desktop_updates/build-…/bundle`.
Die ursprüngliche Installation bleibt erhalten. Erst nach erfolgreichem Bootstrap
aktiviert die neue App den versionierten Verweis `desktop_updates/active.json`.
Beim Start über die ursprüngliche Verknüpfung wird zur neueren Version weitergeleitet.
`--desktop-update-original` startet ausdrücklich die ursprüngliche Installation,
falls eine neue Version nicht startet. Bei inkompatiblen Datenversionen ist zusätzlich
die Sicherung `backups/before_update_….dartbackup` wiederherzustellen. Updates führen
keinen automatischen Daten-Downgrade durch. Vorherige Pakete bleiben für die
Wiederherstellung erhalten und belegen zusätzlichen Speicherplatz.

Archive werden auf SHA-256, Größe, enthaltene Pfade, Dateianzahl, entpackte Größe,
Manifest-Version, Plattform und vollständige Laufzeitdateien geprüft. Symlinks sind
im Update-Archiv nicht erlaubt; der Linux-Paketbau löst sie deshalb beim Packen auf.
Der Helper wartet auf das Ende der bisherigen App, bevor er die neue App startet.

Vor Veröffentlichung auf den jeweiligen Zielsystemen starten und Backup/Restore prüfen.
Ein erfolgreicher Compilerlauf allein ist kein Laufzeittest.

Erster GitHub-Testlauf: https://github.com/ProfGans/DartTunier/actions/runs/36187520493
Die Pakete dieses manuellen Laufs liegen unter Actions → Artifacts; sie werden
nicht nachträglich an den alten Versionstag gehängt. Der nächste neue Versionstag
verwendet den gemeinsamen Release-Ablauf.

Referenzen:
- https://docs.flutter.dev/deployment/ios
- https://docs.flutter.dev/deployment/macos
- https://docs.flutter.dev/platform-integration/linux/setup
