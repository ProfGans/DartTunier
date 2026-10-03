# Ranglistenwertung je Community-Turnier

Beim Erstellen und unter „Turnier bearbeiten“ lässt sich „Zählt zur Community-Rangliste“ umschalten. Bestehende Turniere zählen standardmäßig. Nachträgliche Änderungen gelten für das gesamte Turnier: Elo, Verlauf und Ranglisten-Spielzahlen werden aus den eingeschlossenen Turnieren neu berechnet. Allgemeine Spielerstatistiken und Ergebnisse bleiben unverändert.

Die Änderung benötigt `edit_tournaments`; beim Erstellen gilt `create_tournaments`. Die bestehende serverseitige Prüfung aller Konfigurationsfelder schützt auch diese Einstellung. Keine neue SQL-Spalte ist notwendig: Sie wird im Turnier-Payload gespeichert und über die bestehende Offline-Warteschlange synchronisiert.

Speicherversion 14 ergänzt `countsForRanking`. Fehlende Werte aus Versionen bis 13 werden als `true` gelesen. Der Standardwert wird beim Schreiben ausgelassen, damit ältere unveränderte Turniere keine zusätzlichen Bearbeitungsrechte bei einer reinen Ergebnismeldung benötigen. `false` wird explizit gespeichert. Die bestehende Speicher-Migration erstellt vor dem ersten Schreiben eine Sicherung der alten Version.

## Mehrere Ranglisten

Eine Community hat zunächst die bestehende „Standard-Rangliste“. Unter „Rangliste erstellen“ können Mitglieder mit `edit_community` weitere benannte Ranglisten anlegen. Bei einer Rangliste öffnet sich direkt die Wertung; bei mehreren erscheint zuerst eine Auswahlliste. Die globale Community-Einstellung zum Ein-/Ausschalten bleibt bestehen.

Unter „Gewertete Ranglisten“ werden beim Erstellen/Bearbeiten eines Turniers eine oder mehrere Ranglisten ausgewählt. Jede Wertung berechnet Elo und Verlauf unabhängig aus ihren zugeordneten Turnieren. Eine neue Rangliste übernimmt keine bestehenden Turniere automatisch. Eine leere Auswahl oder `countsForRanking=false` schließt das Turnier aus allen Wertungen aus.

Speicherversion 15 ergänzt `communityRankingIds`. Fehlende Werte werden auf `['default']` migriert; diese Standardzuordnung wird wie bisher ohne zusätzliches JSON-Feld geschrieben. Benutzerdefinierte Zuordnungen werden lokal und im synchronisierten Payload erhalten. Die bestehende Sicherungslogik erstellt vor der Migration ein Versionsbackup.

`202610030002_community_rankings.sql` wurde am 03.10.2026 auf Supabase eingespielt. Die Tabelle speichert zusätzliche Ranglisten; RLS erlaubt Lesen nur Community-Mitgliedern und Erstellen nur mit `edit_community`. Gleichnamige Ranglisten sind innerhalb einer Community nicht erlaubt. Geladene Ranglisten werden accountbezogen für Offline-Nutzung zwischengespeichert. Erstellen erfordert eine Verbindung. Bei einem Ladefehler bleiben gespeicherte Turnierzuordnungen erhalten.
# Elo-Vorschau im laufenden Turnier

Bei aktivierter Community-Rangliste und einem gewerteten Turnier zeigt der aufklappbare Bereich „Spieler · Elo und nächstes Spiel“ die aktuelle Elo jedes zugeordneten Einzelspielers. Bei mehreren dem Turnier zugeordneten Ranglisten ist die Rangliste auswählbar. Wie in der Ranglistenansicht ist zunächst „Dieses Jahr“ aktiv; der Schalter wechselt auf die Gesamtwertung.

Die nächste Paarung kommt aus derselben Order-of-Play-Planung wie die Board-Zuteilung: laufende Spiele zuerst, danach geplante Spiele der aktiven Etappe. Unbekannte Gegner und zukünftige Qualifikationen werden nicht vorausgesagt. Die Vorschau nennt Sieg/Niederlage und bei regulären Gruppenspielen mit passendem Format auch Unentschieden. Teams haben derzeit keine definierte Elo-Wertung.

Die Berechnung verwendet K=32 und dieselbe Rundung wie die Rangliste. Das geöffnete Turnier ersetzt die gespeicherte Kopie anhand seiner ID, sodass lokale Ergebnisse sofort und nur einmal eingehen. Nach Ergebnisänderungen wird lokal neu berechnet; „Elo aktualisieren“ lädt die Community-Daten erneut. Die vorhandenen Repository-Caches ermöglichen Offline-Anzeigen mit dem zuletzt verfügbaren Datenstand. Zwischenzeitliche Ergebnisse anderer Spieler können die Vorschau verändern.

Tests: `test/community_tournament_elo_test.dart` (Berechnung, Zuordnung, Ranglistenfilter, lokale Korrekturen, responsive Anzeige, Fehler/Retry) und `TournamentEloPreview` in der gemeinsamen responsiven Matrix.

## Live-Rangliste im Turnier

Im Elo-Bereich eines gewerteten Community-Turniers schaltet **Live-Rangliste anzeigen** zwischen der Paarungsvorschau und der gesamten ausgewählten Community-Rangliste um. Jahres-/Gesamtwertung und gewählte Rangliste gelten für beide Ansichten. Sichtbar sind Platz, aktuelle Elo, Elo-Differenz und Platzveränderung; neue Einträge werden als „Neu in der Rangliste“ bezeichnet. Spieler ohne gewertete Spiele erscheinen weiterhin nicht. Gleiche Elo-Werte teilen in der Live-Anzeige denselben Platz (1, 1, 3).

Der Vergleich wird aus denselben geladenen Community-Daten **ohne das geöffnete Turnier** rekonstruiert; es handelt sich nicht um einen dauerhaft gespeicherten Stand vom Turnierbeginn. Andere zwischenzeitlich synchronisierte Turniere und Verwaltungsänderungen gehen beim Aktualisieren in beide Vergleichsseiten ein. Das aktuelle lokale Turnier ersetzt eine bereits synchronisierte Kopie anhand seiner ID. Ergebniskorrekturen, vom Geräte-Scorer übernommene Ergebnisse, Ausschlüsse und Resets werden neu berechnet. Für die lokale Live-Anzeige sind keine zusätzlichen Netzwerkabrufe pro Ergebnis notwendig. Externe Community-Änderungen lassen sich über „Elo aktualisieren“ laden.

Tests: `test/community_live_ranking_test.dart` prüft Auf-/Abstieg, Elo-Differenzen, Gleichstände, neue Spieler, Ergebnisrücknahme, Community-/Ranglistenfilter und unmittelbare Aktualisierung ohne erneutes Laden. Die gemeinsame responsive Matrix enthält die Live-Ansicht; kleine Displays, Tablet/Desktop und 200 Prozent Schrift sind abgesichert.

## Spieler entfernen und zurücksetzen

Das neue Rollenrecht **Ranglisten verwalten** (`manage_rankings`) erlaubt Entfernen und Zurücksetzen einzelner Spieler. Community-Eigentümer besitzen es automatisch; bestehende benutzerdefinierte Rollen erhalten es erst durch explizite Zuweisung. Das Erstellen von Ranglisten bleibt beim bisherigen Recht `edit_community`.

In jeder Rangliste öffnet das Drei-Punkte-Menü am Spieler die Aktionen. Ein Bestätigungsdialog erklärt die Wirkung:

- **Entfernen:** Der Spieler verschwindet aus dieser Rangliste. Nachfolgende Spiele mit ihm werden dort für beide Beteiligten nicht gewertet. Bereits berechnete Gegner-Ergebnisse bleiben bestehen. Andere Ranglisten und die Mitgliedschaft bleiben unverändert.
- **Zurücksetzen:** 1000 Elo, null Spiele/Siege/Niederlagen/Unentschieden und ein neuer Elo-Verlauf in dieser Rangliste. Gilt für Jahres- und Gesamtwertung. Ein zuvor entfernter Spieler wird wieder zugelassen und erscheint nach seinem nächsten gewerteten Spiel wieder in der Rangliste.
- **Spieler ohne Ranglistenplatz verwalten:** Ermöglicht Berechtigten dieselben Aktionen für Spieler ohne aktuelle Spiele sowie die Wiederaufnahme entfernter Spieler.

Turnierergebnisse und allgemeine Spielerstatistiken werden nicht gelöscht. Änderungen benötigen eine Online-Verbindung. Die serverseitige Funktion prüft das Recht bei jeder Änderung erneut; ausgeblendete Menüs sind kein Ersatz für den Zugriffsschutz.

`202610030004_ranking_administration.sql` wurde am 03.10.2026 in Supabase eingespielt. Die Ereignistabelle ist für Mitglieder lesbar, aber nicht direkt beschreibbar. Nur die geschützte Funktion `manage_ranking_player` erstellt Ereignisse mit Serverzeit, Bearbeiter und geprüfter Community-/Ranglisten-/Spielerzuordnung. Rollen können keine Rechte weitergeben, die sie selbst nicht besitzen.

Der Verwaltungsverlauf ist anhängend und accountbezogen unter `ranking-actions-v1` zwischengespeichert; ein neues Turnier-JSON-Schema ist nicht erforderlich. Die Elo-Berechnung spielt Ergebnisse vor jeder Verwaltungsaktion ab und wendet dann Entfernen/Reset an. Innerhalb dieser Zeitabschnitte zählt die chronologische Abschlussreihenfolge, auch über mehrere Boards und Turniere hinweg. Bei gleichen Zeitpunkten wird stabil nach Turnierdatum, Turnier-ID und Match-Reihenfolge sortiert. Doppelt geladene Turnier-IDs werden nur einmal berücksichtigt. Die Jahresauswahl verwendet das lokale Erstellungsjahr auch nach UTC-Speicherung. Zeitgrenze ist `finishedAt`; historische Spiele ohne Abschlusszeit verwenden das Erstellungsdatum des Turniers. Auch wiederholte Resets und nachträglich verknüpfte manuelle Spieler bleiben nachvollziehbar. Beide Elo-Ansichten verwenden diesen Verlauf; bei nicht verfügbaren Verwaltungsdaten wird keine ungeprüfte Rangliste angezeigt.

Validierung: `tool/test_ranking_administration.mjs` prüft Eigentümer, delegierte Rechte, Widerruf, Community-Grenzen, Aliasse, Direktzugriffsverbot und RLS. `test/community_ranking_admin_test.dart` prüft Elo, Wiederaufnahme, unveränderte Gegnerhistorie, Aktionsdialoge, Fehlerfälle und 360x800/800x600/1440x900 bei 200 Prozent Schrift. Mobile/Desktop-Vorschauen wurden geprüft; ein physischer Gerätetest steht noch aus.

