# Lokale Turniere importieren

Community → Turniere → „Lokales Turnier importieren“ ist mit `create_tournaments` verfügbar. Die bestehende Speicher- und Serverberechtigung prüft den Schreibvorgang zusätzlich. Der Import erzeugt eine Kopie; das lokale Original bleibt erhalten. Spielplan, Ergebnisse, Zeiten und Scorer-Daten werden mitgenommen. Die Ranglistenwertung ist standardmäßig aus und kann einschließlich Ranglistenwahl aktiviert werden.

Die Import-ID wird deterministisch aus Community- und Quellturnier-ID gebildet. Bereits lokal oder in der Community geladene Kopien werden nicht nochmals angeboten. Importierte Community-Turniere sind keine erneuten Importquellen. Ein anderes lokales Turnier mit eigener ID ist eine eigene Quelle, selbst bei identischem Namen.

Spieler können bestehenden Community-Mitgliedern zugeordnet werden. Gleiche Profil-IDs oder bekannte Aliasse werden vorgewählt; es erfolgt keine automatische Zuordnung allein über Namen. Teilnehmernamen bleiben wegen Bracket-Verknüpfungen erhalten, Profil-IDs werden in den gespeicherten Turnierspielern und Begegnungen ersetzt. Doppelte Zuordnungen werden abgewiesen. Ohne Zuordnung bleiben die vorhandenen Kennungen erhalten; Elo benötigt identifizierbare Community-Mitglieder. Ligaspiel-Roster behalten ihre eigenen gespeicherten Identitäten.

Die Kopie und ihr Upload werden über das vorhandene versionierte Turnierjournal gespeichert. Bei fehlender Verbindung bleibt die Kopie lokal zur späteren Synchronisierung erhalten. Der Community-Synchronisierungsstatus zeigt den Uploadstand. Kein neues Datenbankschema erforderlich.

Prüfung: `test/community_tournament_import_test.dart` prüft Kopie/Original, Spielerkennung in Begegnungen, Ablehnung doppelter Zuordnungen, Schreibberechtigung, Offline-Speicherung und drei Layoutgrößen mit großer Schrift. Die gemeinsame responsive Matrix enthält die Importseite.
