# Profil- und Community-Statistiken

## Bedienung

- Nach der Anmeldung im Hauptmenue oeffnet sich das eigene Profil. Bei bestehender Anmeldung die Account-Karte antippen.
- Scorer ueber das Hauptmenue oder das Profil starten. Beim Spielstart den eigenen menschlichen Teilnehmer auswaehlen. Alternativ ohne Profilzuordnung spielen. Andere Spieler und Bots werden nicht automatisch dem eigenen Profil zugerechnet.
- Erfasste Aufnahmen werden nach Aenderungen lokal gespeichert. Rueckgaengig ersetzt den Stand derselben Spiel-ID. Beim Verlassen wartet die App auf die lokale Speicherung; bei einem Schreibfehler bleibt die Partie offen und bietet Wiederholen an.
- Im Profil erscheinen Gesamtwerte und gespeicherte Spiele mit Detailstatistik. Unvollstaendige Partien werden als nicht beendet angezeigt; ihre vorhandenen Aufnahmen gehen in den Average ein. Dieser wird nach Darts gewichtet. Unbekannte Checkoutversuche bleiben unbekannt.
- Jede Community hat einen neuen Bereich **Statistik**. Er zeigt Spiele, Siege, Unentschieden, Niederlagen sowie erfasste Legs und Sets ihrer gespeicherten Turniere. Gruppen- und KO-Ergebnisse werden beruecksichtigt. Annullierte Spiele und Freilose zaehlen nicht. Verknuepfte Gastprofile werden ihrem Account zugeordnet.
- Community-Zahlen werden aus den bestehenden, gespeicherten Turnierdaten berechnet. Korrekturen wirken damit auch auf die Statistik, ohne separate Zaehler mehrfach zu erhoehen. Der bestehende Turnierupload beim Abschluss bzw. manuellen Synchronisieren bleibt erhalten.
- Aus Leg-/Set-Ergebnissen werden keine detaillierten Scorerwerte erfunden. Fruehere Scorer-Sitzungen ohne gespeicherte Aufnahmen koennen nicht nachtraeglich rekonstruiert werden.

## Highlight-Liste der Community

Unter **Community → Statistik → Highlight-Liste** stehen automatische Scorer-Highlights und manuelle Einträge. Automatische Einträge zeigen pro Spieler/Team und Turnier den erfassten Average, das höchste Checkout, das kürzeste Leg und die Anzahl 180er, sofern diese Daten vorhanden sind. Turnierübergreifende Bestwerte werden damit nicht behauptet. Das Datum ist das Turnierende, ersatzweise das Erstellungsdatum des Turniers. Verschiedene Spielformate können unterschiedliche Leistungen ergeben; Teams behalten gemeinsame Werte.

Die Liste ist durch Freitext, Kategorie, Spieler/Team, Turnier, Herkunft und einen inklusiven Datumsbereich filterbar. Mit **Highlights verwalten** können Mitglieder Einträge hinzufügen sowie bestehende manuelle und automatische Einträge bearbeiten oder löschen. Änderungen an automatischen Highlights gelten nur für diese Liste und sind als manuelle Korrektur gekennzeichnet. Die Spielergebnisse, Elo und übrigen Statistiken werden dadurch nicht verändert.

Speicherung: `community_highlights` enthält manuelle Einträge, Korrekturen und Löschmarkierungen. Automatische Schlüssel setzen sich aus Turnier-ID, Spieler-ID und Kategorie zusammen. Dadurch erscheinen gelöschte Highlights nach dem Neuladen nicht erneut. Automatische Korrekturen werden nicht mehr angezeigt, wenn ihre Quelldaten fehlen. Der vorhandene Turnierdatensatz beim Öffnen der Rubrik liefert die automatischen Einträge; Aktualisieren lädt die gespeicherten Highlight-Änderungen und Rechte erneut.

Die Servermigration `202610030005_community_highlights.sql` ist eingespielt. RLS begrenzt Lesen auf Community-Mitglieder und Schreiben auf das neue Recht. Bearbeiter und Änderungszeit werden serverseitig gesetzt. Schreiben benötigt Internet; bereits geladene Einträge werden accountbezogen unter `community-highlights-v1` zwischengespeichert und offline als gespeicherter Stand gekennzeichnet. Das Turnier-JSON bleibt unverändert.

Tests: `test/community_highlights_test.dart`, bestehende Turnier-Highlights, Community-Navigation, Rollenlayout und responsive Matrix; SQL-Rechteprüfung mit `node tool/test_community_highlights.mjs`. Liste und Editor sind für 360x800, 800x600, 1440x900 und große Schrift geprüft. Gerenderte Mobile-/Desktop-Vorschauen sind kontrolliert; reale Smartphone-Tests stehen aus.

## Zeitraumfilter im Profil

Der Filter bietet Gesamt, Heute, die letzten 7 oder 30 Kalendertage, den aktuellen Monat, das aktuelle Jahr und einen frei waehlbaren Datumsbereich. Er gilt gemeinsam fuer Scorer-Gesamtwerte, die gespeicherte Spieleliste und Turnierstatistiken. Anfangs- und Endtag sind inklusive und richten sich nach der lokalen Zeitzone. Die Auswahl bleibt beim Synchronisieren und beim Wechsel der Fenstergroesse erhalten.

Scorer-Spiele werden anhand ihres gespeicherten Beginns (`playedAt`) eingeordnet. Turnierspiele verwenden `finishedAt`, ersatzweise `startedAt`; das Erstellungsdatum eines Turniers ersetzt kein fehlendes Spieldatum. Alte Ergebnisse ohne beide Angaben erscheinen deshalb nur unter Gesamt. Turniere speichern bereits `createdAt` und `updatedAt`, Matches Start und Ende. Diese bestehenden ISO-Zeitfelder werden jetzt einheitlich mit UTC-Zeitzone geschrieben; das Schema bleibt kompatibel und alte Werte werden weiterhin gelesen. Ergebniskorrekturen behalten die urspruengliche Abschlusszeit.

## Speicherung und Servereinrichtung

Die lokale Turnierdatei hat Schema **7**. Das neue Feld `playerStatistics` enthaelt je Account und Spiel-ID den versionierten Scorer-Datensatz und seinen ausstehenden Uploadstatus. Bestehende Turniere bleiben erhalten; vor der Migration wird die bisherige Datei gesichert. Vorhandene Backups nehmen diese Daten bereits ueber `tournaments.json` mit auf. Aeltere App-Versionen koennen Schema 7 nicht lesen.

Online werden eigene Scorer-Sitzungen in `public.player_match_statistics` gespeichert. Zugriff nur auf eigene Daten, abgesichert durch Row Level Security. Uploads erfolgen nach Spielabschluss, bei Rueckgaengig nach Abschluss, beim Verlassen und beim Oeffnen/Aktualisieren des Profils. Ohne passenden Online-Account bleiben die Daten lokal; Fehler lassen den ausstehenden Upload erhalten. Downloads lassen noch nicht hochgeladene lokale Aenderungen unangetastet.

**Auf dem bestehenden Supabase-Projekt muss einmal die folgende Migration ausgefuehrt werden:**

`supabase/migrations/202610010001_player_match_statistics.sql`

Dazu den Inhalt im SQL-Editor des App-Supabase-Projekts ausfuehren. Die Tabelle und Policies sind auch in `supabase/schema.sql` fuer Neuinstallationen enthalten. Die Migration wurde in dieser Entwicklungsumgebung nicht auf dem Server ausgefuehrt: Ein Datenbank-Adminzugang steht hier nicht zur Verfuegung. Bis dahin funktioniert die lokale Statistik; der Profilabgleich zeigt einen Online-Fehler und behaelt die Daten fuer einen erneuten Versuch.

Die Community-Statistik benoetigt keine zusaetzliche Tabelle: Ihre Quelle ist das bereits synchronisierte `tournaments.payload`. Ein fremdes Community-Mitglied kann hierdurch keine privaten Scorer-Aufnahmen anderer Accounts lesen.

## Pruefung

In der Spielerauswahl bei der Community-Turniererstellung kann der Community-Inhaber neue manuelle Spieler anlegen. Die bestehende serverseitige Inhaber-Regel für `community_guest_members` bleibt maßgeblich. Nach erfolgreicher Speicherung wird die zurückgegebene Profil-ID direkt ausgewählt; bestehende Auswahl bleibt erhalten. Fehler behalten den Namen für einen erneuten Versuch. Ein bereits angelegtes Mitglied bleibt beim Abbrechen der Turnierauswahl bestehen und kann später einem Account zugeordnet werden.

Automatische Highlights zählen die Maxima 162, 165, 168, 171, 174, 177 und 180 einzeln aus nicht überworfenem Scoring. Short Legs sind abgeschlossene Legs mit höchstens 18 Darts; ihre Häufigkeit wird nach Dartzahl aufgeschlüsselt. Community-Liste und Turnier-Endscreen verwenden dieselben Regeln. Bestehende gespeicherte Aufnahmen werden neu berechnet, das Speicherschema bleibt unverändert. Manuell bearbeitete Highlights behalten ihre gespeicherte Korrektur. Grenzfälle sind in `test/scorer_highlight_rules_test.dart` abgesichert.

### Community-Trends

Unter Statistik → Trends werden die letzten drei Kalendermonate einschließlich heute mit den drei Monaten davor verglichen. Monatsenden werden auf den letzten gültigen Tag begrenzt; die Intervalle überschneiden sich nicht. Grundlage ist die Ergebnisquote `(Siege + 0,5 × Unentschieden) / Spiele`. Mindestens fünf Spiele in jedem Zeitraum und eine Veränderung von mindestens ±15 Prozentpunkten ergeben „Spieler im Aufwind“ bzw. „Ab ans Practice Board“. Sonst erscheinen „Stabile Form“ oder „Noch zu wenig Vergleichsdaten“. Dies beschreibt Ergebnisse, nicht gegnerbereinigte Spielstärke.

Die vorhandene Community-Statistik übernimmt Community-Abgrenzung, Alias-Zuordnung, Turnier-Deduplizierung und Ausschluss annullierter Spiele. Gewöhnliche Spiele benötigen Abschluss- oder Startzeit; Ligaspiele verwenden das Turnierdatum. Der gewichtete Average wird ergänzend angezeigt, bestimmt die Kategorie aber nicht. Die Seite benötigt keine neue Speicherung, Serverabfrage oder aktivierte Rangliste. `test/community_trends_test.dart` prüft Zeitgrenzen, Mindestmengen, Unentschieden, Korrekturen, Navigation und responsive Layouts.

- `test/player_statistics_test.dart`: Migration, Neustart, getrennte Accounts, wiederholte Speicherung, Offline-Wiederholung, Aenderung waehrend Upload, gewichteter Average, unbekannte Checkoutversuche, Gruppen-/KO-Zaehler und Korrekturen.
- `test/profile_scorer_widget_test.dart`: Spielergebnis speichern, Rueckgaengig, Speichern beim Verlassen und Behandlung eines Schreibfehlers.
- `test/community_menu_test.dart`: Zugang zum neuen Statistikbereich.
- `test/responsive_pages_test.dart`: Profil und Community-Statistik in der gemeinsamen Groessen-/Schriftmatrix; optionale PNG-Vorschauen.

Serverseitige Migration und RLS muessen nach der Installation zusaetzlich mit zwei echten Accounts geprueft werden. Die lokalen Synchronisierungstests verwenden simulierte Uploads/Downloads; sie ersetzen keinen Live-Test der Supabase-Konfiguration.
