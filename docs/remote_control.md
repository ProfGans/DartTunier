# Fernsteuerung in der installierten App

## Verbinden

1. Die aktualisierte App auf Hauptgerät und Handy öffnen. Beide Geräte müssen sich im selben lokalen Netzwerk befinden.
2. Am Hauptgerät unter **Geräte → App fernsteuern** die Freigabe aktivieren. Sie bleibt als Einstellung gespeichert und wird nach einem App-Neustart wieder gestartet. **Freigabe beenden** schaltet sie dauerhaft aus.
3. Auf dem Handy unter **Geräte → Anderes Gerät fernsteuern** den QR-Code scannen oder IP-Adresse und vollständigen Kopplungscode eingeben. Bei mehreren Netzwerkadaptern den QR-Code der WLAN-/LAN-Adresse wählen, die das Handy erreichen kann.
4. Die angezeigte Oberfläche bedienen: Antippen, Ziehen und Scrollen wirken auf die laufende Sitzung des Hauptgeräts. Für kleine Elemente zunächst **Zoom / Verschieben**, anschließend **Bedienen** wählen.
5. Für Texte ein Eingabefeld am Hauptgerät antippen und **Text eingeben** öffnen. **Übernehmen** aktualisiert das Feld einschließlich seiner bestehenden Eingabeprüfung. **Eingabe bestätigen** löst die Abschlussaktion des fokussierten Feldes aus.

**Zurück am Hauptgerät** bedient dessen Navigator. Der Zurück-Pfeil in der Handy-App verlässt die Fernsteuerung. **Trennen** lässt die Sitzung auf dem Hauptgerät unverändert weiterlaufen. Eine erneute Verbindung lädt die aktuelle Oberfläche; Eingaben werden bei einem Abbruch nicht nachträglich wiederholt.

Die Freigabe ist auf jeder Hauptgeräte-Ansicht sichtbar und kann dort sofort beendet werden. Bei jeder neuen Freigabe wird ein neuer Code erzeugt. Ein Hauptgerät akzeptiert genau eine Fernbedienung gleichzeitig. Beim Fernsteuern pausiert das Handy seine eigene Freigabe vorübergehend; beim Verlassen der Fernsteuerungsseite wird sie bei weiterhin aktivierter Einstellung wieder gestartet.

## Gleicher Account und Bestätigung

Unter **Geräte → App fernsteuern → Übernahme bestätigen** lässt sich die Bestätigung pro Hauptgerät ein- oder ausschalten. Der Standard ist **aus**, entsprechend dem gewünschten direkten Zugriff. Die Einstellung wird zusammen mit der Freigabe versioniert in `remote_control.json` gespeichert.

- **Aus:** Ein authentifiziertes Gerät verbindet direkt. Geräte desselben Accounts benötigen keinen QR-Code. Für andere Geräte bleibt der Kopplungscode erforderlich.
- **Ein:** Jede authentifizierte Verbindung, auch mit Kopplungscode, wartet auf **Übernahme erlauben** oder **Ablehnen** am Hauptgerät. Ohne Antwort wird die Anfrage nach 90 Sekunden abgelehnt. Vor der Zustimmung werden weder Bilder noch Eingaben übertragen.

Auf beiden Geräten mit demselben Online-Account anmelden. Auf dem Hauptgerät die Freigabe aktivieren. Auf dem Handy unter **Fernsteuerbare Geräte meines Accounts** das Hauptgerät auswählen. Seine Freigabe wird automatisch über den Account registriert; die bestehende Board-Geräteregistrierung ist dafür nicht erforderlich. Die App verwendet bevorzugt die im LAN gefundene Adresse und probiert andernfalls die registrierten IPv4-Adressen. Nach einer tatsächlichen Verbindung oder Bestätigungsanfrage gibt es keine automatische Wiederholung von Übernahmen.

Ein Account-Wechsel oder Abmelden widerruft den lokalen Account-Zugang und trennt die betreffende Fernsteuerung. Ein bereits per QR-Code freigegebenes Gerät ist davon unabhängig. Wenn eine Verbindung abbricht, bleibt die Hauptgeräte-Sitzung erhalten.

### Einmalige Servereinrichtung

Für Account-Verbindungen muss `supabase/migrations/202610030006_account_remote_control.sql` im bestehenden Supabase-Projekt eingespielt werden. Die Migration wurde lokal geprüft, aber in dieser Sitzung nicht auf dem Live-Server ausgeführt: Es steht kein verbundener Supabase-Verwaltungszugang zur Verfügung. Die lokale Bestätigungseinstellung und QR-Verbindungen funktionieren unabhängig von dieser Migration.

Die Tabelle `account_remote_devices` enthält pro Gerät einen zufälligen, aktuellen Freigabeschlüssel und dessen LAN-Adressen. Row-Level Security erlaubt ausschließlich dem angemeldeten Eigentümer das Lesen und Ändern; anonyme Nutzer und andere Accounts können weder Schlüssel lesen noch Freigaben überschreiben. Die App lädt den Account-Schlüssel über die bereits authentifizierte HTTPS-Verbindung. Login- oder Refresh-Tokens werden nicht an andere LAN-Geräte gesendet. Der Account-Schlüssel ist vom QR-Schlüssel getrennt und wird lokal beim Beenden oder Account-Wechsel ungültig. Beim regulären Beenden wird außerdem der Servereintrag gelöscht; nach einem Absturz kann ein veralteter Eintrag sichtbar bleiben, dessen Schlüssel beim nächsten Start nicht mehr akzeptiert wird.

Die Registrierung und das Abrufen der Account-Freigabe benötigen Internetzugriff auf Supabase. Die anschließende Steuerung läuft direkt im LAN. Ohne Account-Dienst bleibt die lokale Verbindung per QR-Code möglich.

## Funktionsumfang und Grenzen

Die Fernbedienung spiegelt die gesamte Flutter-Oberfläche, einschließlich Navigation, Turnieren, Scorer, Autoscoring, Einstellungen, App-Dialogen und Board-Anzeige. Fachlogik, Kameraverarbeitung, Kontositzung und Speicherung bleiben auf dem Hauptgerät. Es entsteht keine zweite Kopie des Turnierzustands; die Turnier-Persistenz bleibt unverändert.

Das Hauptgerät muss geöffnet sein und seine Oberfläche rendern können. Die Verbindung ist für WLAN/LAN vorgesehen, ohne Internet-Relay. Die Firewall muss TCP-Port **45875** zulassen. Ein Gast-WLAN mit Geräteisolierung verhindert die Verbindung. Die vorhandene Geräteerkennung und Board-Übertragung behalten ihre eigenen Ports und Kopplungen.

Native Betriebssystemfenster, etwa der Datei-Auswahldialog, externe Browser für Anmeldung und Betriebssystem-Berechtigungen, gehören nicht zur gespiegelten Flutter-Oberfläche und müssen am Hauptgerät bedient werden. Live-Kamera-Texturen und die Last beim gleichzeitigen Autoscoring müssen zusätzlich auf realer Hardware geprüft werden. Die Spiegelung liefert Bedienbilder mit bis zu vier Bildern pro Sekunde und ist kein Video-Streamingdienst.

## Architektur und Übertragung

Eigenes Feature unter `lib/features/remote_control/`: Application-Controller für Host und Client, ein verschlüsselter Kanal unter `data/`, versionierter QR-Code unter `domain/`, getrennte Widgets unter `presentation/`. `main.dart` bleibt Bootstrap. Die App-Shell stellt den Host-Scope und eine RepaintBoundary über den vollständigen Navigator bereit.

Pro Verbindung wird eine neue Zufalls-Challenge erzeugt. Der 256-Bit-Kopplungscode authentifiziert den Client mit HMAC-SHA256. Für jede Übertragungsrichtung werden eigene Sitzungsschlüssel abgeleitet. Oberflächenbilder und Bedienaktionen werden mit AES-256-GCM verschlüsselt; streng fortlaufende Sequenznummern verhindern Wiederholung. Der Client prüft den Host durch dessen erste authentifiziert verschlüsselte Antwort. Der Code wird nicht im Netzwerk übertragen oder gespeichert.

Nur ein Bild wartet gleichzeitig auf Bestätigung. Eine ausgebliebene Bildbestätigung beendet die Verbindung nach 15 Sekunden. Socket-Pings erkennen abgebrochene Verbindungen. Fensterwechsel verwerfen alte Koordinaten und brechen laufende Fernbedienungs-Gesten ab. Texteingaben sind an das tatsächlich fokussierte Eingabefeld gebunden; Passwörter werden nicht als Klartext ins Texteditor-Metadatum übernommen. Alle Texte werden über `EditableTextState` mit den vorhandenen Formatierern verarbeitet.

## Prüfungen

```powershell
flutter analyze
flutter test test/remote_control_test.dart test/remote_account_control_test.dart test/remote_control_widget_test.dart test/remote_settings_widget_test.dart
flutter test test/adaptive_layout_test.dart test/responsive_pages_test.dart
flutter test test/tournament_simulation_matrix_test.dart
```

Netzwerktests prüfen echte Loopback-Verbindungen, falsche Codes, konkurrierende Clients, Bildbestätigung, geordnete Eingaben, Wiederverbindung, Widerruf und Abbruch während des Startens. Kanaltests prüfen Verschlüsselung, Manipulation und Replay. Widgettests prüfen Remote-Touch, Scrollen, Texteingabe mit Formatierern, veraltete Feld- und Fensterdaten sowie 360x800, 800x600 und 1440x900 mit 100/200 Prozent Schrift.

Optionale gerenderte Vorschauen:

```powershell
flutter test test/remote_control_widget_test.dart --dart-define=LAYOUT_PREVIEW_FONT=C:/Windows/Fonts/segoeui.ttf
```

Vorschauen liegen unter `build/layout_previews/remote_*.png`. Die Tests ersetzen keinen physischen Windows-/Handy-Durchlauf mit Kameras und WLAN. iOS enthält eine Beschreibung für den lokalen Netzwerkzugriff; iOS wurde in der Windows-Umgebung nicht gebaut.

`test/remote_account_control_test.dart` prüft direkte Account-Übernahme, Zustimmung, Ablehnung, Abbruch während der Anfrage, Widerruf beim Abmelden, persistierte Einstellungen und fehlgeschlagene Speicherung. `test/remote_settings_widget_test.dart` prüft Einstellungsoberfläche, Account-Auswahl und Bestätigungsdialog in der responsiven Matrix; mit `LAYOUT_PREVIEW_FONT` entstehen zusätzliche PNGs. `node tool/test_remote_control_accounts.mjs` prüft die SQL-Migration zweimal sowie Account-Trennung, anonyme Ablehnung und Schlüsselvalidierung mit PGlite.
