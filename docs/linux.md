# Linux-Funktionen und Einrichtung

Die Linux-Erweiterungen sind für x64 und ARM64 implementiert. Die lokalen Dart-,
Widget-, SQL- und Worker-Tests ersetzen keinen Test auf einem echten Linux-Desktop.
Insbesondere USB-Kameras, Ton, Desktop-Benachrichtigungen, Links und Update-Neustarts
müssen vor Veröffentlichung auf dem Zielgerät geprüft werden.

## Systempakete

Für Ubuntu 22.04 oder ein kompatibles 64-Bit-Debian-System, etwa Raspberry Pi OS
Bookworm Desktop 64-Bit:

```sh
sudo apt-get update
sudo apt-get install libgtk-3-0 libstdc++6 libsecret-1-0 libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 gstreamer1.0-plugins-base gstreamer1.0-plugins-good ffmpeg v4l-utils tesseract-ocr tesseract-ocr-eng espeak-ng libnotify-bin python3 xdg-utils
```

Es werden keine Dateien auf diesem Rechner installiert. Diese Befehle gehören auf
das Linux-Zielgerät. Ein grafischer Desktop und eine normale Benutzeranmeldung
werden vorausgesetzt. Die App nicht als root starten.

## Speicherung

Turnier-JSON, SQLite-Datenbank und Instanzsperre verwenden dieselbe zentrale
Pfadauflösung. Linux verwendet den Anwendungsdatenordner von `path_provider`
unter XDG_DATA_HOME beziehungsweise `~/.local/share` und benötigt kein APPDATA.
Wenn eine alte Installation über APPDATA bereits `tournaments.json` oder
`app_database.sqlite` in `DartTournamentManager` angelegt hat, bleibt dieser
explizit konfigurierte Pfad erhalten. APPDATA dafür nicht entfernen, bevor die
alten Daten per Backup in die neue Installation übertragen wurden. Es gibt keine
automatische Kopie laufender Datenbanken und keine Änderung des Datenformats.

## Kamera, QR und automatische Kalibrierung

Der Linux-Adapter verwendet V4L2 (`/dev/video*`) und einen eigenen FFmpeg-Prozess
pro Kamera. Metadaten-Geräte werden herausgefiltert. Die aktuelle Capture-Vorgabe
ist 1280×720 mit fünf Vorschaubildern pro Sekunde; die Kamera muss diesen Modus
anbieten. Bei nicht passenden oder belegten Kameras wird ein Fehler angezeigt.
`v4l2-ctl --list-devices` hilft bei der Zuordnung. USB-Rechte und Bandbreite für
drei gleichzeitig angeschlossene Kameras müssen auf dem Zielgerät passen.

QR-Scanner für Scorer-Beitritt und Fernsteuerung verwenden denselben Adapter.
Manuelle Codes bleiben verfügbar. Automatische Zahlenerkennung verwendet Tesseract
lokal; Bilder und Trefferberechnung verlassen den Rechner nicht. Die Genauigkeit
und Geschwindigkeit auf Raspberry Pi hängen von Kamera, Licht und Modell ab und
sind noch nicht praktisch bestätigt.

Treffer-/Bounce-Sounds verwenden GStreamer und funktionieren unabhängig von einer
installierten Stimme. Deutsche Ansagen verwenden `espeak-ng`. Es gibt weder
Shell-Auswertung des gesprochenen Textes noch einen Cloud-Sprachdienst.

## App-Menü und Einladungslinks

Das vollständige Release-Archiv entpacken und im Paketordner ausführen:

```sh
python3 install-desktop.py
```

Das registriert einen Menüeintrag und `dartturnier://` für den aktuellen Benutzer.
Der Ordner muss bestehen bleiben. Ein Link öffnet das vorhandene App-Fenster;
es wird keine zweite schreibende Instanz gestartet. Der Desktop-Updater wartet
beim Versionswechsel auf das Ende der bisherigen Instanz, bevor er neu startet.

## Nachrichten bei geschlossenem App-Fenster

Im Hauptmenü unter Linux-Benachrichtigungen online anmelden, Gerätenamen vergeben
und **Hintergrundempfang aktivieren**. Dies richtet explizit einen
`systemd --user`-Dienst ein, der bei der Benutzeranmeldung startet. Er ruft etwa
alle 30 Sekunden Nachrichten und aktivierte Kalendererinnerungen ab und zeigt
sie über `notify-send` an. Bei Fehlern wartet er 60 Sekunden. Dieser Empfang ist
Polling und kein Firebase-Push. Bei ausgeschaltetem Rechner oder abgemeldetem
Linux-Benutzer erscheinen keine Meldungen; gültige Nachrichten können nach der
nächsten Anmeldung nachgeholt werden.

Der Dienst speichert nur einen zufälligen 256-Bit-Geräteschlüssel in einem privaten
Ordner (0700, Datei 0600), keinen Konto-Refresh-Token. Der Server speichert dessen
Hash. Die API erlaubt damit nur Abruf, Bestätigung und Widerruf dieses Gerätes.
Andere Geräte und Kontodaten sind nicht lesbar. Nachrichten haben maximal 24 Stunden
Gültigkeit; Kalendererinnerungen enden 15 Minuten nach Terminbeginn. Bei Austritt,
Abbestellung oder Terminänderung werden veraltete Erinnerungen nicht zugestellt.
Ein Absturz genau zwischen Anzeige und lokaler Bestätigung kann eine Meldung
erneut anzeigen; ein genau-einmal-Zustellversprechen wird nicht gegeben.

**Deaktivieren** stoppt den Dienst zuerst lokal und widerruft den Empfangsschlüssel.
Bei Kontoabmeldung/-wechsel stoppt eine appweite Überwachung den Dienst ebenfalls.
Schlägt der Server-Widerruf offline fehl, bleibt der Schlüssel für den nächsten
Versuch erhalten; der lokale Dienst ist bereits gestoppt. Im Menü kann die
Deaktivierung erneut versucht werden.

### Noch erforderliche Server-Veröffentlichung

`supabase/migrations/202610030007_linux_notifications.sql` nach den bestehenden
Push- und Kalender-Migrationen anwenden und die aktualisierte Edge Function
`send-app-push` veröffentlichen. Der Versand bleibt auf die bestehende
serverseitige Senderliste begrenzt. Für reine Linux-Empfänger ist kein Firebase-
Dienstkonto erforderlich; Android benötigt es weiterhin.

Diese Serveränderungen wurden lokal mit PostgreSQL-kompatiblen Tests geprüft,
aber in dieser Änderung **nicht live deployt**. Ohne sie schlägt die Linux-
Geräteregistrierung kontrolliert fehl. Es wurde keine Nachricht an echte Nutzer
gesendet und kein Hintergrunddienst auf dem Windows-Entwicklungsrechner angelegt.

## Validierung

- `flutter analyze`
- `flutter test test/linux_platform_test.dart test/linux_notification_widget_test.dart test/desktop_update_test.dart test/backup_service_test.dart test/app_database_test.dart test/autoscore_audio_test.dart`
- `flutter test test/adaptive_layout_test.dart test/responsive_pages_test.dart`
- `node tool/test_linux_notifications.mjs` (bestehende PGlite-Testinstallation)
- `node tool/test_linux_push_worker.mjs`
- `python3 tool/test_linux_worker.py`

Die Linux-CI führt zusätzlich echte FFmpeg-/Tesseract-Werkzeugtests aus. Hardware-
und Desktop-Sitzungstests stehen weiterhin aus; keine 32-Bit-Linux-Unterstützung.
