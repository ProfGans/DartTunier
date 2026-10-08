# Turnierrechte

Community-Turniere besitzen einen serverseitig bestimmten Ersteller. Der Ersteller,
pro Turnier hinzugefügte Leiter und Mitglieder mit `lead_tournaments` erhalten die
Turnierleitungsübersicht. Alle übrigen Mitglieder öffnen die normale Übersicht.
Lokale Turniere bleiben auf dem lokalen Gerät verwaltbar.

Bei der Community-Turniererstellung stehen drei Ergebnisfreigaben zur Verfügung:

- Nur Turnierleitung (auch der sichere Standard für ältere Turniere).
- Turnierleitung und ausgewählte Community-Mitglieder.
- Alle Community-Mitglieder.

Ersteller und Mitglieder mit `edit_tournaments` können die Freigaben anschließend
über **Turnierrechte** ändern. Eine Ernennung zur Turnierleitung erlaubt nicht,
weitere Leiter zu ernennen. Entfernte Community-Mitglieder verlieren ihre Rechte
auch dann, wenn ihre ID noch in einer alten Turnierzuweisung steht.

Zusätzliche Ergebnisschreiber melden ausschließlich erste Ergebnisse offener
Spiele der aktiven Etappe online. Korrekturen, Annullierungen, Auslosung, Boards
und Etappenwechsel bleiben der Leitung vorbehalten. Die Ergebnis-RPC prüft
Mitgliedschaft, Freigabe, Paarung, Startzeit und zulässigen Spielstand erneut.
Sie übernimmt niemals den kompletten Turnierstand des Ergebnisschreibers.
Die Leitung lädt eingegangene Ergebnisse über **Online-Stand laden**; dabei
übernimmt die normale Turnierlaufzeit das Weiterkommen. Das Nachladen ersetzt
noch nicht synchronisierte lokale Änderungen erst nach einer Bestätigung.

## Bereitstellung

`supabase/migrations/20261008120000_tournament_access.sql` muss zusammen mit der
neuen App ausgerollt werden. Am 08.10.2026 nur lokal getestet, nicht produktiv
angewendet. Der produktive Server besitzt noch keine `save_community_tournament_v2`.
Die Migration baut auf `202610020001_community_permissions.sql` auf.

Die neue App verwendet `save_community_tournament_v2` und `submit_tournament_result`.
`syncRevision` verhindert das Überschreiben inzwischen eingegangener Ergebnisse.
Ältere Clients kennen die Revision nicht; nach einem neuen Online-Schreibvorgang
können ihre weiteren Uploads abgelehnt werden. Vor Aktivierung alle schreibenden
Clients aktualisieren. Ausstehende Änderungen nicht durch Zurücksetzen der
Versionsprüfung erzwingen, sondern den Online-Stand bewusst übernehmen.

Lokales Speicherschema 19 ergänzt die optionalen Rechte und Revisionen;
die parallel ergänzte Geräte-Startfunktion verwendet bereits Schema 20.
Alte Dateien werden mit sicheren Standardwerten gelesen und vor Migration gesichert.

Die getrennte RHL-Ligaspielverwaltung und importierte Challonge-Archive verwenden
ihre bisherigen Abläufe; die zusätzlichen Ergebnisschreiber betreffen die regulären
Community-Turnieretappen (Gruppen und KO samt Sonderformen).

## Prüfung

- `node tool/test_tournament_access.mjs`: echte PostgreSQL-Regeln mit PGlite,
  Rollenwechsel, Rechteentzug, Manipulationen, Ergebnisvalidierung und Konflikte.
- `flutter test test/tournament_access_test.dart`: Rechtematrix, geschlossene
  Berechtigungsprüfung, eingeschränkter Ergebnisdialog und responsive Auswahl.
- Zusätzlich Turniersimulation, gemeinsame Responsive-Matrix, Speichermigration
  und bestehende Community-Turniertests.
- Mit `--dart-define=LAYOUT_PREVIEW_FONT=C:/Windows/Fonts/segoeui.ttf` entstehen
  Vorschauen unter `build/layout_previews/access_*.png`.

Keine Live-Mehrgeräte- oder physischen Gerätetests durchgeführt.
