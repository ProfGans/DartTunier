# Scorer-Einstieg und Kontobeitritt

Der Scorer startet mit drei Spielarten: Spieler, Bots und Spieler & Bots.
Die Formulare erlauben nur passende Gegnertypen, jeweils auch mehrere Gegner.
Spielerpartien benötigen mindestens zwei Menschen, Botpartien einen Menschen
und mindestens einen Bot, gemischte Partien mindestens zwei Menschen und einen Bot.
Gastnamen bleiben ohne Internet nutzbar. Das angemeldete Gastgeberkonto ist
automatisch Teilnehmer 1 und behält seine bestehende Profilstatistik-Zuordnung.

Technische Bot-Feinabstimmung und manuelle Scoring-/Checkout-Stärke gibt es nur
unter Einstellungen → Scorer & Bots. Im Spielaufbau bleibt bei aktiviertem
Theo-Modus der Theo-Average pro Bot einstellbar. Alte manuelle Vorgaben werden
unverändert übernommen und lassen sich nur in den Einstellungen ändern.

## Online-Lobby

Im Spieler- und gemischten Menü öffnet „QR-Code & Einladungen öffnen“ eine Lobby.
Gäste wählen Scorer → Spiel beitreten, melden sich mit ihrem eigenen Online-Konto
an, scannen den Code und bestätigen den Beitritt. Android, iOS, macOS und Web
verwenden die Kamera. Windows verwendet eine integrierte Webcam-Vorschau mit
Kameraauswahl und lokaler QR-Erkennung. Linux bietet weiterhin die Code-/Link-Eingabe. Native Links
verwenden `dartturnier://scorer/join?code=…`. Der Scanner basiert auf
[mobile_scanner](https://pub.dev/packages/mobile_scanner); Kameraberechtigungen
sind für Android/iOS/macOS ergänzt. Ein verweigerter Zugriff blockiert nicht die
alternative Code-Eingabe. Unter Windows nutzt der Scanner das offizielle
[camera_windows](https://pub.dev/packages/camera_windows)-Plugin und
[zxing_lib](https://pub.dev/packages/zxing_lib) zum lokalen Decodieren.
Er öffnet die Webcam ohne Mikrofon, prüft regelmäßig ein Kamerabild und entfernt
die vom Plugin angelegte temporäre Bilddatei unmittelbar nach dem Einlesen.
Kamerabilder werden nicht hochgeladen. Verlassen, Kamerawechsel und Wechsel in
den Hintergrund geben die Kamera frei. Der Einstieg heißt „Kamera öffnen · QR scannen“
unter Scorer → Spiel beitreten.

„Aus Gruppen einladen“ bietet ausschließlich echte Konten aus gemeinsamen
Communities an. Manuell angelegte Gruppennamen ohne Konto sind keine Empfänger.
Die eingeladene Person erhält bei geöffneter App ein Pop-up mit Annahme/Ablehnung.
Die Inbox wird im Vordergrund alle acht Sekunden geprüft; nach Rückkehr in die App
sofort. Es handelt sich nicht um Betriebssystem-Push bei geschlossener App.
Ein weggeklicktes Pop-up wird in derselben App-Sitzung nicht ständig wiederholt.

Bestätigte Konten werden beim Gastgeber alle drei Sekunden aktualisiert und über
ihre Konto-ID dedupliziert. Ihre Namen sind im Spielaufbau nicht überschreibbar.
Gastnamen und angemeldete Teilnehmer können nebeneinander verwendet werden.
Das gemeinsame Match läuft auf dem Gastgebergerät am Board. Gastkonten werden
als Teilnehmeridentitäten geführt; ihre persönlichen Cloud-Matchstatistiken
werden durch diesen Beitritt noch nicht auf den Gastgeräten gespeichert.

## Server einrichten

Zusätzlich zum bestehenden Supabase-Schema muss
`supabase/migrations/202610020002_scorer_lobbies.sql` im SQL-Editor des zugehörigen
Supabase-Projekts oder über den bestehenden Migrationsprozess ausgeführt werden.
Die Migration wurde am 02.10.2026 nach ausdrücklicher Freigabe auf dem App-Projekt
`hnsyvqtqxdsbbyrayobv` über den Supabase-SQL-Editor erfolgreich ausgeführt.
Die drei Tabellen, aktivierte RLS, gesperrte direkte Tabellenzugriffe und die
RPC-Ausführungsrechte wurden auf dem Server geprüft. Ein Live-Funktionstest in
einer vollständig zurückgerollten Transaktion bestätigte Lobby-Erstellung,
Einladungs-Inbox, Annahme/Ablehnung, QR-Code-Beitritt, Kontoidentität,
Deduplizierung, Teilnehmerentfernung, Fremdzugriffsschutz, Schließen und Ablauf.
Es bleiben keine Testeinladungen oder Testpartien aus dieser Transaktion bestehen.
Ein echter Smartphone-Kameratest und ein Ende-zu-Ende-Test auf zwei Geräten
stehen weiterhin aus. Für andere Supabase-Projekte ist die Migration separat
auszuführen; die Migration nicht erneut auf bereits eingerichteten Tabellen starten.

Schema v1 verwendet eigene Tabellen für Lobbys, Mitglieder und Einladungen.
Direkter Tabellenzugriff ist gesperrt (RLS und Grants); die authentifizierte RPC
`scorer_lobby_action` prüft Gastgeber, Empfänger und gemeinsame Mitgliedschaft
serverseitig. Beitritte verwenden ausschließlich `auth.uid()`, nie vom Gastgeber
übermittelte Konto-IDs. Zufällige QR-Codes laufen nach zwei Stunden ab. Beim
Spielstart schließt die RPC die Lobby unter Zeilensperre und liefert die finale
Teilnehmerliste. Verspätete Beitritte werden abgelehnt. Verlassen schließt die
Lobby bestmöglich; nach App-Abbruch greift das Ablaufdatum. Eine neue Lobby
schließt frühere offene Lobbys desselben Gastgebers.

## Prüfung

`flutter test test/scorer_lobby_test.dart test/scorer_wizard_test.dart`
prüft Modusregeln, Linkvalidierung, mehrere Gegner, bestätigte Teilnehmer,
Einladungs-Pop-up, Beitritt, Schließfehler und Größenwechsel mit 200% Text.
`test/responsive_pages_test.dart` enthält Wizard, alle drei Aufbauten und Beitritt.
`flutter test test/scorer_camera_test.dart` prüft den Windows-Kameralebenszyklus
mit simulierter Hardware, Kamerasperren/Wiederholung, Dateibereinigung, tatsächliches
QR-Decodieren aus Testbildern und die Scanneroberfläche bei 200% Schrift.

`node tool/test_scorer_lobbies.mjs` führt die Migration in einer lokalen
PostgreSQL/PGlite-Instanz aus und prüft Autorisierung, Fremdzugriffe, QR-Beitritt,
Gemeinschaftsprüfung, Annahme/Ablehnung, Ablauf und geschlossene Lobbys.
Voraussetzung wie beim vorhandenen Community-SQL-Test:
`npm install --prefix build/rbac_sql_tests --no-audit --no-fund --ignore-scripts @electric-sql/pglite`.
