# Releases für weitere Plattformen

Der Workflow `.github/workflows/android-release.yml` heißt nun **App Release**.
Ein neuer Tag passend zu `pubspec.yaml` baut Android, Windows, Linux und macOS.
Erst nach erfolgreichen Android-Prüfungen und allen Desktop-Builds wird ein
gemeinsamer Release-Entwurf mit SHA256SUMS angelegt. Manuelle Workflow-Starts
erzeugen ausschließlich Actions-Artefakte. Bestehende Releases werden nicht verändert.

- Windows: x64 ZIP mit EXE, DLLs und Datenverzeichnis. Vollständig entpacken.
  Noch keine Authenticode-Signatur. Eventuell benötigt der Rechner die Microsoft
  Visual C++ Redistributable x64 Laufzeit.
- Linux: x64 tar.gz, gebaut auf Ubuntu 22.04. GTK 3 und kompatible Systembibliotheken
  erforderlich; kein universelles Paket für alle Distributionen.
- macOS: App-ZIP mit den vom Flutter-Build erzeugten Architekturen, ohne
  Developer-ID-Zertifikat und Notarisierung. Gatekeeper kann den Start blockieren.
- iOS: separater unsignierter Release-Build als Actions-Artefakt zur Build-Prüfung.
  **Keine installierbare IPA und kein GitHub-Release-Asset.** Für TestFlight/App Store
  müssen Apple-Developer-Mitgliedschaft, registrierte Bundle-ID, Signierungszertifikat,
  Provisioning und App-Store-Connect-Zugang eingerichtet werden. Diese Daten gehören
  ausschließlich in GitHub Secrets, niemals in das Repository.

Für macOS ist als nächster Schritt Developer-ID-Signierung plus Notarisierung nötig.
Die bestehenden Bundle-IDs bleiben bis zur abgestimmten Apple-Einrichtung unverändert,
damit sich bisherige Speicherorte nicht durch Umbenennung ändern.

Desktop-Pakete ersetzen keine Benutzerdaten und enthalten keine lokalen Speicherstände.
Vor dem manuellen App-Wechsel Backup exportieren und App schließen. Die automatische
Update-Suche innerhalb der App ist weiterhin nur für Android implementiert.

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
