# Community-Rollen und Rechte

Unter **Community → Rollen & Rechte** lassen sich benannte Rollen erstellen,
bearbeiten und angemeldeten Mitgliedern zuweisen. Pro Mitglied gilt eine Rolle.
Manuell angelegte Teilnehmer ohne Account erhalten keine Verwaltungsrechte.

Die acht getrennten Rechte sind:

- Rollen erstellen und zuweisen
- Turniere erstellen
- Mitgliedereinladungslink teilen (einschließlich QR-Code)
- Turniere löschen
- Turniere bearbeiten
- Mitglieder entfernen
- Geräte zuteilen
- Turniere leiten

Der Inhaber besitzt immer alle Rechte und kann nicht entfernt oder einer anderen
Rolle zugeordnet werden. Ohne Rolle ist ein Mitglied lesend berechtigt.
Bestehende Administratoren erhalten bei der Migration die Rolle Administration.
Rollenverwalter dürfen ausschließlich eigene Rechte weitergeben und keine
höher berechtigten Rollen oder deren Zuweisungen verändern.

Bearbeiten umfasst aktuell Name und Boardanzahl. Turnierleitung erlaubt den
Spielbetrieb und die Ergebniseingabe. Geräte lassen sich über die Turnieraktionen
auch ohne Turnierleitungsrecht zuweisen; eine physische Gerätekopplung bleibt
zusätzlich erforderlich. Die Zuteilungsansicht muss für den Betrieb geöffnet bleiben.

## Offline und Synchronisierung

Offline gelten die zuletzt für den aktuellen Account geladenen Rechte.
Ergebnisse werden zuerst lokal zusammen mit dem ausstehenden Upload gespeichert.
Die laufende App synchronisiert ausstehende Änderungen alle zwei Minuten sowie
beim Start und bei Rückkehr in den Vordergrund. Bei Turnier- oder Ligaabschluss
erfolgt sofort ein zusätzlicher Versuch; auch manuelles Synchronisieren bleibt möglich.
Fehlgeschlagene Uploads bleiben über Neustarts erhalten. Erfolgreiche Uploads
entfernen nur den unveränderten Outbox-Eintrag, nicht die lokale Turnierkopie.
Lokale Turniere ohne Community bleiben weiterhin lokal.
Es erfolgt keine Supabase-Abfrage bei jeder Ergebniseingabe. Der Server prüft
bei jedem Upload die aktuellen Rechte erneut; entzogene Rechte verhindern damit
die spätere Veröffentlichung. Lokale Änderungen bleiben bei einer Ablehnung erhalten.

Löschen ist online erforderlich, damit die aktuellen Rechte geprüft werden.
Auch noch nicht synchronisierte Entwürfe können gelöscht werden. Serverseitig
gelöschte Turniere werden beim nächsten Laden aus den lokalen Community-Daten
einschließlich ihrer ausstehenden Uploads entfernt und können nicht wieder
hochgeladen werden.

## Serverinstallation

Die Migration `supabase/migrations/202610020001_community_permissions.sql`
ist nach dem Basisschema sowie den Migrationen für manuelle Mitglieder,
Account-Geräte und Community-Geräte einmalig auszuführen. Sie läuft atomar.
Das Basisschema anschließend nicht erneut ausführen: Es enthält ältere Policies.

**Am 02.10.2026 auf dem Produktivprojekt `hnsyvqtqxdsbbyrayobv` ausgeführt.**
Die zuvor fehlende Migration für manuelle Mitglieder wurde ebenfalls ausgeführt.
Anschließend wurden beide Rollentabellen mit RLS, alle sechs Rollen-RPCs,
der Turnier-Schutztrigger, die Mitgliedertabelle und die Sperre des direkten
Lesens von Einladungscodes auf dem Server erfolgreich geprüft.

Die Migration erneuert bestehende Einladungscodes. Alte Links und QR-Codes
funktionieren danach nicht mehr; berechtigte Mitglieder können neue teilen.
Einladungscodes werden ausschließlich über einen berechtigten RPC abgerufen.
Ältere App-Versionen, die die Community mit allen Spalten abfragen, sind mit
dieser Zugriffsbeschränkung nicht kompatibel. Deshalb alle Geräte aktualisieren.

## Prüfung

`test/community_permissions_test.dart` prüft getrennte Rechte, Delegation,
geschützte lokale Speicherung und entfernte Turniere.
Die responsive Seitenmatrix enthält Rollenverwaltung und Rolleneditor.

`node tool/test_community_permissions.mjs` führt die Migration und
Zugriffsversuche in einer lokalen PostgreSQL-Umgebung aus. Voraussetzung:
`npm install --prefix build/rbac_sql_tests --no-audit --no-fund --ignore-scripts @electric-sql/pglite`.
Die temporäre Testabhängigkeit gehört nicht zu den App-Abhängigkeiten.
