# Ligaspiele

Die Ligaansicht bietet Mannschaftsvergleich (gespielte Matches, Siege,
Niederlagen, Legs und Mannschaftspunkte), Spielkarten und den aufklappbaren
Bereich „Boards und Geräte“. Die Boardzahl kann ohne laufende Spiele geändert
werden. „Starten“ weist ein Match einem freien Board zu. Das Geräte-Pairing,
die Übertragung und Ergebnisprüfung verwenden dieselben Komponenten wie andere
Turniere. Doppelpartner sind Teil der Belegungsprüfung.

`LeagueBoardRuntime` projiziert die 18 Ligaspiele in die bestehenden
`OrderOfPlayController`-/`DeviceResultImporter`-Modelle. Gespeichert wird die
Liga einschließlich Boardstatus und Geräteergebnis (Ligadokument v2,
Turnierspeicher v11); ältere Ligadokumente v1 bleiben lesbar.

## Spieler und Einladungen

Neben jedem Aufstellungsplatz öffnet das Personensymbol die Auswahl. Lokale
Spieler können ausgewählt oder neu erstellt werden. Community-Konten erhalten
eine Einladung für Heim/Gast und den gewählten Platz. Erst eine angenommene
Einladung übernimmt den Spieler einschließlich Profil-ID. Über „Einladungen
aktualisieren“ werden Antworten geladen. Offene/abgelehnte Einladungen müssen
angenommen oder zurückgezogen werden, bevor das Ligaspiel angelegt wird.

Der Empfänger sieht die Einladung in der geöffneten, angemeldeten App und kann
annehmen oder ablehnen. Dies ist keine Betriebssystem-Push-Benachrichtigung.
Einladungen laufen nach zwei Tagen ab. Die ungespeicherte Aufstellung bleibt
ein Formularentwurf; vor dem Verlassen offene Einladungen zurückziehen.

Für Online-Einladungen muss zuerst die Migration
`supabase/migrations/202610020005_league_invitations.sql` auf dem Server
ausgeführt werden. Sie setzt die bestehende Community-/Profilstruktur und für
die Kandidatenauswahl die Scorer-Lobby-Migration voraus. Die Tabellen sind per
RLS gesperrt; nur die RPC erlaubt dem Gastgeber Einladungen an Konten einer
gemeinsamen Community und nur dem Empfänger deren Annahme/Ablehnung. Lokale
Spieler und Liga-Geräte benötigen diese Migration nicht.

Tests: `league_board_runtime_test.dart`, `league_invitation_test.dart`,
`rhl_league_widget_test.dart`, `league_statistics_test.dart`,
`tournament_simulation_matrix_test.dart` sowie die responsive Testmatrix.
