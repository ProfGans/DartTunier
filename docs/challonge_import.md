# Alte Challonge-Turniere in eine App-Community übernehmen

In der Ziel-Community unter **Turniere → Challonge-Turniere importieren**:

1. Den öffentlichen Turnierlink eingeben, beispielsweise `https://challonge.com/de/DCUH202637`. Der API-Schlüssel bleibt leer.
2. **Importvorschau laden** öffnet die öffentliche Seite im eingebauten Browser und liest anschließend die offizielle Rangliste. Eine eventuell angezeigte Browserprüfung selbst abschließen und **Seite erneut prüfen** wählen.
3. Alternativ **Turniere laden** mit dem vorausgefüllten Community-Link verwenden. Auf der Challonge-Seite **PAST** auswählen, die Liste laden lassen und **Seite erneut prüfen** drücken. Erfasst werden die Links auf der aktuell geladenen Seite. Weitere Seiten beziehungsweise fehlende Turniere über einzelne Links ergänzen.
4. Die Vorschau kontrollieren. Gleiche Mitgliedsnamen werden nach Groß-/Kleinschreibung und Leerzeichen abgeglichen. Abweichende Namen bestehenden Mitgliedern zuordnen. Mehrdeutige Namen benötigen eine ausdrückliche Zuordnung.
5. **Turniere und fehlende Mitglieder importieren** übernimmt die Auswahl. Fehlende Teilnehmer werden als Community-Mitglieder ohne Benutzerkonto angelegt. Nach den bestehenden Serverregeln braucht das Anlegen neuer Mitglieder den Community-Eigentümer; der Turnierimport braucht „Turniere erstellen“. Es werden keine Challonge-Konten angelegt und keine Einladungen versendet.

## Ergebnisse und Wiederholung

Originalspielstände, Sieger, Verlierer, Runden und offizielle Endplatzierungen bleiben im Archiv erhalten. Gruppenplatzierungen werden getrennt gespeichert. Für Spieler ohne veröffentlichte Gesamtplatzierung wird kein Gesamtplatz erfunden. Der historische Turnierbaum wird nicht neu berechnet.

Einzelne ganzzahlige Spielstände wie `3-1` werden bei passendem Sieger als Legs in die bestehende Statistik übernommen. Mehrteilige Spielstände bleiben unverändert im Archiv. Ranglisten/Elo sind bei neuen Importen zunächst deaktiviert. Das Archivformat Version 2 ergänzt Gruppenplätze und liest weiterhin Version 1.

Die öffentliche Seite liefert häufig nur das Startdatum. Es wird als Startdatum und historisches Erstellungsdatum übernommen; ein fehlender Abschlusszeitpunkt bleibt leer. JSON/API-Exporte benötigen weiterhin ihre historischen Erstellungs- und Abschlussdaten. Unvollständige Daten, unbekannte Spielerkennungen und Teamturniere werden abgewiesen.

Die Importkennung ist pro Ziel-Community und Challonge-ID eindeutig. Wiederholungen überspringen gespeicherte Turniere und verwenden bereits angelegte Mitglieder wieder. Ein abgebrochener Import lässt sich dadurch wiederholen. Der bestehende lokale Speicher und die Community-Synchronisierung speichern das Archiv.

## Zugriff und Prüfung

Der normale Browserzugriff benötigt keinen API-Schlüssel. Die Challonge-Seite führt ihre üblichen Seitenskripte im Browser aus; der Parser liest ausschließlich DOM und eingebettetes JSON und führt dessen Inhalt nicht aus. Browserdaten liegen im normalen lokalen Browserprofil, unter Windows im App-Datenordner. Sie werden nicht mit dem Turnier gespeichert. Hauptnavigation bleibt auf HTTPS-Challonge-Seiten beschränkt. Windows benötigt Microsoft Edge WebView2. Browserprüfungen werden nicht automatisiert umgangen.

Der reine HTTP-Zugriff auf die Beispielseite antwortete mit HTTP 403; die Seite war im normalen Browser öffentlich lesbar. Am 8. Oktober 2026 wurden die echten Strukturen von [DCUH202637](https://challonge.com/de/DCUH202637) geprüft: sieben Teilnehmer, 21 Gruppenspiele und vier K.-o.-Spiele einschließlich Spiel um Platz 3. Endplätze: Max_Re, Jan_Wa, Mike_Ro, Marvin_S. Alle sieben Gruppenplätze werden gesondert erhalten. Die übrigen drei Spieler erhalten keine erfundene Gesamtplatzierung.

Der automatisierte Test `test/challonge_public_bracket_test.dart` bildet diese beobachteten Spieldaten ohne Bild-/Kontometadaten nach und prüft auch abweichende Gruppen-Spielerkennungen. Import-, Speicher-, Turniermatrix- und responsive Tests ergänzen die Prüfung. Ein authentifizierter Import in eine echte Ziel-Community und eine Sichtprüfung auf physischen Smartphones wurden nicht durchgeführt.

Der optionale API-Zugang und vollständige JSON-Dateien bleiben verfügbar. Der API-Schlüssel wird nur vorübergehend an `api.challonge.com` gesendet und nicht gespeichert.

Prüfstatus: Flutter-Analyse ohne Befunde; Importtests, Turniermatrix und responsive Regressionstests erfolgreich. Desktop- und Mobile-PNG-Vorschauen wurden angesehen. Der isolierte Windows-Debug-Build unter build/challonge_windows_check/runner/Debug wurde einschließlich Browserplugin erfolgreich gebaut. Die laufende App wurde nicht beendet oder ersetzt; ein nativer Browser-Durchlauf und ein Schreibimport in die echte Community sind noch nicht geprüft.
