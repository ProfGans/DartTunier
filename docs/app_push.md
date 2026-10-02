# App-Push von ProfGans

## Aktueller Umfang

Der Hauptmenue-Button **Push-Nachricht senden** erscheint nur, wenn der angemeldete Supabase-Account in der serverseitigen Tabelle `app_push_senders` eingetragen ist. Anzeigenamen sind keine Berechtigungen. Desktop und Android koennen die Versandseite bedienen. Der Empfaenger waehlt auf Android **Push-Empfang aktivieren**, vergibt einen Geraetenamen und erlaubt Benachrichtigungen. Dafuer ist eine Online-Anmeldung erforderlich.

Implementiert ist der Android-Empfang ueber Firebase Cloud Messaging, inklusive Vordergrundanzeige und Systembenachrichtigung bei geschlossener App. Windows-, iOS- und Web-Empfang sind noch nicht implementiert. Android-Force-Stop in den Systemeinstellungen verhindert Push bis zum naechsten manuellen App-Start. Die Zustellung haengt von Netzwerk, Google Play Services und Android-Berechtigungen ab.

Die Firebase-Abhaengigkeit benoetigt fuer iOS-Builds mindestens iOS 15; das Xcode-Deployment-Target wurde entsprechend angehoben. Ein iOS-Build wurde hier nicht ausgefuehrt. Androids automatische Firebase-Messaging-Registrierung bleibt bis zur Aktivierung des Empfangs deaktiviert.

## Noch erforderliche Einrichtung

1. Firebase-Projekt `darttunier-6f866`: Android-App mit Paketnamen `de.dartturnierverwaltung.app` registrieren bzw. vorhandene App verwenden. `google-services.json` nach `android/app/google-services.json` legen. Die Datei wird nicht eingecheckt. Release-CI verwendet optional das GitHub-Secret `FIREBASE_ANDROID_GOOGLE_SERVICES_BASE64` (Base64 dieser Datei). Ohne Konfiguration startet die App weiterhin, Push meldet jedoch nicht verfuegbar.
2. `supabase/migrations/202610020003_app_push.sql` im App-Supabase-Projekt ausfuehren. Sie ist eine eigenstaendige Migration nach dem bestehenden Basisschema.
3. Den echten ProfGans-Account anhand seiner bestaetigten E-Mail bzw. Auth-Benutzer-ID identifizieren und genau diese UUID freischalten: `insert into public.app_push_senders(user_id) values ('VERIFIZIERTE-AUTH-UUID') on conflict do nothing;`. Niemals alle Profile mit gleichem Anzeigenamen freischalten.
4. Firebase Cloud Messaging HTTP v1 aktivieren. Den berechtigten Firebase-Service-Account als Supabase-Edge-Secret `FIREBASE_SERVICE_ACCOUNT_JSON` hinterlegen. **Keine privaten Schluessel in App, Git oder Chat speichern.**
5. Edge Function `send-app-push` bereitstellen. Sie verifiziert den Supabase-Bearer-Token selbst und prueft die Versandberechtigung bei jeder Anfrage. Falls die Supabase-Gateway-JWT-Pruefung mit dem Projekt-Signaturtyp inkompatibel ist, mit `--no-verify-jwt` deployen; die Authentifizierung im Handler bleibt verbindlich.
6. Einen neuen Android-Build installieren, Empfang aktivieren und mit einem bewusst ausgewaehlten Testgeraet testen. Hier wurde keine Nachricht an echte Nutzer gesendet. Die Datenbankmigration und Senderfreischaltung sind inzwischen auf dem Server eingerichtet; ein echter Zustelltest steht noch aus.

Die vom Nutzer bereitgestellte Android-Konfigurationsdatei wurde am 02.10.2026 fuer Projekt und Paketnamen validiert und lokal unter `android/app/google-services.json` eingebunden. Sie bleibt durch Git ausgeschlossen. Fuer Release-Builds muss das oben genannte GitHub-Secret separat eingerichtet werden.

Der Nutzer hat die Login-E-Mail seines Hauptaccounts angegeben. Der passende bestaetigte Auth-Account und seine UUID wurden im Supabase-Dashboard schreibgeschuetzt verifiziert. Die lokale, nicht eingecheckte Datei `build/push_setup/enable_profgans_push.sql` kombiniert die Migration mit einer transaktionalen Freischaltung: Sie erwartet genau den bestaetigten Auth-Account mit dieser E-Mail und der verifizierten UUID und speichert diese UUID in der Senderliste. Die Migration samt Freischaltung wurde am 02.10.2026 nach ausdruecklicher Freigabe im Supabase-Projekt ausgefuehrt. Die anschliessende Serverabfrage bestaetigte: ProfGans freigeschaltet, genau ein berechtigter Account, alle drei Push-Tabellen mit aktivierter Row Level Security. Firebase-Serversecret und Bereitstellung der Edge Function stehen noch aus. `build/push_setup/firebase_android_config_base64.txt` enthaelt den vorbereiteten Wert fuer das GitHub-Secret. Beides wird bei einer Bereinigung des Build-Verzeichnisses entfernt.

## Versand und Sicherheit

Auswahl einzelner registrierter Geraete; hoechstens 100 pro Anfrage. Titel bis 80, Nachricht bis 1000 Zeichen. Die Anzeige unterscheidet Uebergabe an FCM von tatsaechlicher Anzeige auf dem Geraet. Registrierungen aelter als 90 Tage werden ausgeblendet; beim App-Start bzw. Wiederaufnehmen werden sie erneuert.

Die App uebergibt ausschliesslich Geraete-IDs; Tokens bleiben serverseitig. Nur Serverrollen verwalten die Senderliste. Ungueltige FCM-Tokens werden entfernt. Der Client behaelt fuer unveraenderte Versanddaten dieselbe Anfrage-ID, und eine atomare Serverreservierung verhindert doppelte Sendungen bei Wiederholung. Bei einem Serverabbruch nach der Reservierung bleibt die Anfrage auf `processing`; automatische Wiederholung wird bewusst vermieden, da ein Teil bereits zugestellt sein kann. Ein Zeitlimit beim Provider kann ebenfalls eine bereits erfolgte Zustellung nicht ausschliessen.

## Pruefung

`flutter test test/app_push_test.dart` prueft Sichtbarkeit, grosse Schrift, mobile/Tablet/Desktop-Breiten und Wiederholungen. `node tool/test_app_push.mjs` prueft die SQL-Migration mit lokalem PGlite einschliesslich Privilegien, gleichnamigem Fremdaccount und Token-Zugriff. Ein echter Firebase/Supabase-Zustelltest ist nach der Einrichtung erforderlich.
