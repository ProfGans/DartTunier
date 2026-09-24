# Dart Turnierverwaltung

Flutter-App zur Verwaltung von Dart-Turnieren.

## Geräte

Im Hauptmenü unter **Geräte** lässt sich **Als Gerät bereitstellen** aktivieren.
Name und Gerätemodus bleiben in `devices.json` (Schema-Version 2) gespeichert.
Version 1 wird beim Laden um einen zufälligen Kopplungsschlüssel ergänzt;
Geräte-ID, Name, Gerätemodus und gemerkte Geräte bleiben erhalten.
Die Installation besitzt eine stabile, zufällige Geräte-ID. Solange die App
geöffnet ist, bleibt ein aktivierter Computer auch außerhalb der Geräte-Seite
auffindbar. Ohne Gerätemodus antwortet die App nicht als Anzeigegerät.

Andere Computer im lokalen IPv4-Netz werden per UDP auf Port 45873 erkannt
(Broadcast und Multicast-Gruppe 239.255.77.77, Protokollversion 1). Die Firewall
muss den Verkehr zulassen; isolierte Gastnetze/VPN-Routen können die Erkennung
verhindern. Die Geräte-Seite sucht alle fünf Sekunden lokal, Geräte verschwinden
nach 90 Sekunden ohne Lebenszeichen aus der Fundliste. Alle 15 Sekunden wird
die Netzwerksuche neu verbunden, auch nach Socketfehlern oder einem WLAN-Wechsel.
Bekannte Geräte werden zusätzlich direkt angesprochen. Android hält den
Multicast-Empfang während aktiver Suche im Vordergrund frei; im Hintergrund wird
die Freigabe wieder aufgehoben. **Hinzufügen** merkt die
Geräte-ID lokal; IP-Adressen sind keine dauerhafte Geräteidentität.

Für Account-Geräte zuerst `supabase/migrations/202609220001_account_devices.sql`
ausführen. Auf jedem Computer mit demselben Online-Account anmelden und
**Diesen Computer dem Account hinzufügen** wählen. Registrierung und Entfernung
brauchen Internet. Account-Listen werden nur beim Öffnen/Aktualisieren geladen;
es gibt keine periodischen Cloud-Heartbeats. Registrierung bedeutet nicht online.

Die Account-Registrierung ist durch Supabase-RLS auf den jeweiligen Benutzer
beschränkt und reserviert die Geräterolle `match_display`.

### Spiele auf Anzeigegeräte übertragen

1. Auf dem Anzeigegerät den Gerätemodus aktivieren und die App geöffnet lassen.
2. Auf der Turnierleitung die Turnieransicht öffnen und oben
   **Boards auf Geräte übertragen** wählen.
3. Für ein Board ein gefundenes Gerät wählen und **Anfrage senden** drücken.
4. Die sechsstellige Vergleichszahl auf beiden Geräten vergleichen und am
   Zielgerät **Koppeln** drücken. Keine Code-Eingabe erforderlich.

Die Anfrage läuft nach 60 Sekunden ab. Die Kopplung verwendet einen eigenen,
flüchtigen X25519-Schlüsselaustausch; weder der dauerhafte Geräteschlüssel noch
der Sitzungsschlüssel werden über das Netzwerk übertragen. Die Vergleichszahl
bindet die Bestätigung an diesen Austausch. Die Implementierung nutzt
[cryptography X25519](https://pub.dev/documentation/cryptography/latest/cryptography/X25519-class.html).
Android-Empfang verwendet einen
[MulticastLock](https://developer.android.com/reference/android/net/wifi/WifiManager.MulticastLock).

Pro Board wird ein Gerät gekoppelt. Die Anzeige folgt alle fünf Sekunden der
bestehenden Order-of-Play-Planung: laufendes Spiel, sonst das nächste für dieses
Board geplante Spiel als Vorschau. Spielergebnisse und Etappenwechsel werden
automatisch übernommen. Start und Ergebniseingabe bleiben in der Turnierleitung.
Auf dem Empfänger öffnet sich die Anzeige automatisch; **Zur Verwaltung**
minimiert sie, **Zur Spielanzeige** öffnet sie wieder.

Zuordnungen und die auf der Turnierleitung eingegebenen Schlüssel gelten nur
für die geöffnete Turnieransicht. Beim Schließen werden die Zuordnungen gelöst.
Ohne Lebenszeichen zeigt der Empfänger nach 20 Sekunden einen Verbindungsabbruch
an. **Kopplungen zurücksetzen** auf dem Empfänger widerruft vorhandene Kopplungen.

Übertragung im lokalen Netzwerk per HTTP/TCP 45874, ohne Supabase-Abfragen.
Empfänger und Nachrichten werden mit HMAC-SHA256 und einmaligen, kurzlebigen
Challenges authentifiziert; der Kopplungsschlüssel wird nicht über das Netzwerk
übertragen. Der Nachrichteninhalt ist im LAN nicht verschlüsselt. Die Erkennung
allein berechtigt nicht zum Steuern. Eine zweite Turnierleitung wird abgewiesen,
solange die erste Verbindung aktiv ist. Internet-Relay und Ergebniseingabe auf
dem Anzeigegerät sind noch nicht Teil dieser Ausbaustufe.

## Projektstruktur

Die App wird schrittweise modularisiert, damit spaetere Features sauber erweitert werden koennen. Die verbindlichen Hinweise fuer kuenftige Codex-Sitzungen stehen in [AGENTS.md](AGENTS.md).

Die aktuelle Architektur-Notiz und der empfohlene Refactor-Plan stehen in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Entwicklung

```powershell
flutter analyze
flutter test
```

## Online-Communities konfigurieren

Communities verwenden ein Supabase-Projekt. Die Zugangsdaten werden nicht im
Quellcode hinterlegt. Beim lokalen Start muessen deshalb die URL des aktiven
Projekts und dessen Publishable/Anon-Key uebergeben werden:

```powershell
flutter run --dart-define=SUPABASE_URL=https://<projekt-ref>.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

Ohne diese Angaben laeuft die App im lokalen Account-Modus; Communities sind
dann bewusst nicht verfuegbar. So fuehrt eine geloeschte oder falsche
Supabase-Hostadresse nicht zu endlosem Laden.

### Datenbank-Migrationen

Nach `supabase/schema.sql` die SQL-Dateien aus `supabase/migrations/` in
Dateinamen-Reihenfolge im Supabase SQL Editor ausfuehren (auch bei neuen Projekten).
`202609210001_manual_community_members.sql` ergaenzt manuelle Community-Mitglieder.
Nur der Community-Inhaber darf sie anlegen und einem bereits beigetretenen
Account zuordnen. Anlegen und Zuordnen benoetigen Internet; geladene Mitglieder
werden fuer die Offline-Turnierauswahl zwischengespeichert.
Die eigene Spieler-ID bleibt bei einer Zuordnung erhalten. Die Rangliste ordnet
alte Ergebnisse beim Berechnen dem ausgewaehlten Account zu; eine geaenderte oder
aufgehobene Zuordnung wirkt entsprechend auch auf die bisherigen Ergebnisse.

### Gruppenmitgliedschaft von Geraeten

Unter **Geraete → Als Geraet einer Gruppe beitreten** kann der aktuelle Computer
mit Einladungscode oder Einladungslink einer Community beitreten. Auch die
Einladungsseite bietet diesen Beitritt an. Ein angemeldeter Online-Account und
Internet sind erforderlich; der Computer wird dabei beim Account registriert.
Die separate Rolle `device` erscheint in der Geraeteliste der Gruppe und erzeugt
keinen Spieler, Ranglisteneintrag oder Zugriff auf Spielerdaten. Die Gruppen
dieses Computers und der Austritt stehen auf der Geraeteseite bereit.
Die LAN-Anzeige muss weiterhin ueber den zuschaltbaren Geraetemodus aktiviert
und mit der Turnierleitung gekoppelt werden. Gruppenmitgliedschaft allein ist
keine Freigabe zur Steuerung. Es gibt kein Cloud-Polling fuer Gruppen-Geraete.

Servervoraussetzung: Nach `202609220001_account_devices.sql` auch
`supabase/migrations/202609230001_community_devices.sql` ausfuehren.
Diese Migration ist im Repository vorbereitet, nicht automatisch deployed.
RLS und RPC pruefen Account und Besitz; das Entfernen der Account-Registrierung
entfernt auch deren Geraetemitgliedschaften. Serverseitige Rechte muessen nach
dem Deployment mit zwei Accounts geprueft werden.

### Einladungslinks und QR-Codes (App-Registrierung)

QR-Codes enthalten `dartturnier://community/join?code=XXXXXXXX`.
Android, iOS und macOS registrieren das Schema ueber ihre App-Manifeste.
Die Windows-App registriert es beim Start fuer den aktuellen Windows-Benutzer;
Links werden an eine bereits laufende Instanz weitergegeben.
Nach einer Neuinstallation bzw. unter Windows nach dem ersten Start oeffnet
der Link die Einladung mit vorbelegtem Code. Anmeldung und Beitritt bleiben
explizite Aktionen. Code oder Link lassen sich alternativ im Beitrittsdialog einfuegen.

Die App muss installiert sein; es gibt noch keine Web-/Store-Ausweichseite.
QR-Scanner muessen benutzerdefinierte URL-Schemata unterstuetzen. Android-Test:
`adb shell am start -a android.intent.action.VIEW -d 'dartturnier://community/join?code=ABCDEFGH'`.
iOS-Simulator-Test: `xcrun simctl openurl booted 'dartturnier://community/join?code=ABCDEFGH'`.

