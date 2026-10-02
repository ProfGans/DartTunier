# Profilbildauswahl – Plattformprüfung

Community- und Spielerprofile verwenden `shared/images/profile_image_picker.dart` und denselben Encoder. JPG, PNG und WebP werden über den System-Dateidialog gewählt. Dateiendungen, MIME-Typen und Apple-UTIs sind gesetzt; zuvor fehlten die UTIs im Spielerprofil.

Der Import begrenzt Dateigröße und tatsächlichen Datenstrom auf 5 MiB, prüft die Bildabmessungen vor dem Decodieren (20 Megapixel) und speichert ein 256×256-JPEG bis 128 KiB Base64. Auf nativen Plattformen arbeitet der Encoder in einem Isolate; auf Web gilt die Größenbegrenzung ebenfalls. Abbrechen erhält das bisherige Bild. Fehler geben die Bedienung wieder frei; parallele Dialoge sowie UI-Updates nach dem Schließen einer Seite werden verhindert. Ungültige gespeicherte Spielerbilder erhalten eine Ersatzanzeige.

## Windows

Am 02.10.2026 wurden lokale WER-Ereignisse für `dart_tournament_manager.exe` gefunden: Abstürze in `flutter_windows.dll` und ein `AppHangB1`. Diese belegen den Fehler, aber nicht seine genaue Ursache oder einen eindeutigen Zusammenhang mit einem bestimmten Bild.

Der installierte `file_selector_windows` führt `IFileDialog::Show` synchron auf dem Plattformthread aus. Flutter 3.41.4 führt standardmäßig auch Dart auf diesem Thread aus. Der Windows-Runner setzt deshalb als Kompatibilitätsmaßnahme `UIThreadPolicy::RunOnSeparateThread`. Dadurch bleibt Dart außerhalb der verschachtelten Windows-Dialogschleife. Das gilt auch für Backup-Dateidialoge. Die Option muss bei späteren Flutter-Upgrades erneut geprüft werden; Flutter kündigt ihren späteren Wegfall an.

Ein vollständiger Neustart der neu gebauten EXE ist nötig; Hot Reload übernimmt Runner-Änderungen nicht. Der konkrete native Dateidialog-Absturz ist hier noch nicht vor/nach dem Fix reproduziert worden.

## Prüfumfang

- Windows: nativer Build; Unit-/Widgettests für Import, Abbrechen, Lesefehler, Mehrfachklicks, Seitenwechsel, ungültige Bilder, Größenlimits und Speichern.
- Android: Debug-APK kompiliert; System-Dokumentauswahl benötigt keine zusätzliche pauschale Speicherfreigabe.
- iOS: UTI-Filter und registrierter Dokumentpicker geprüft; kein iOS-Gerät/Mac-Compiler verfügbar.
- macOS: Plugin und `com.apple.security.files.user-selected.read-write` in Debug/Release geprüft; kein nativer Build auf Windows möglich.
- Linux: Pluginregistrierung und Endungs-/MIME-Filter geprüft; kein Linux-Laufzeittest.
- Web: separater Browser-Test `test/profile_image_web_test.dart` für den gemeinsamen Bildimport vorhanden. Der Chrome-Testlauf blieb beim Laden hängen und wurde abgebrochen; Browserfunktion deshalb nicht bestätigt. Die vollständige App ist weiterhin durch native SQLite-/`dart:ffi`-Imports nicht webfähig; das ist unabhängig vom Bildimport.

Manuelle Abnahme auf jedem Zielsystem: beide Profilarten öffnen; JPG/PNG/WebP auswählen und speichern; Auswahl abbrechen; ungültige/zu große Datei wählen; Dialog erneut öffnen; Fenstergröße/Rotation ändern. Insbesondere unter Windows Öffnen, Abbrechen, Auswählen und erneutes Öffnen mit der neuen EXE prüfen.
