# Ranglisten verwalten

In einer Rangliste öffnet **Ranglisten-Regeln / Löschen** die Verwaltung.
Erforderlich ist `manage_rankings`. Das gilt auch für die Standard-Rangliste.

Eine Gültigkeit von 1 bis 120 Kalendermonaten ist optional. Der Stichtag
ist einschließlich; bei kurzen Monaten wird der Tag auf das Monatsende
begrenzt. Spiele werden nach ihrem Abschlussdatum gefiltert. Bei alten
Ergebnissen ohne Zeitstempel dient das Turnier-Erstellungsdatum als Ersatz.
Elo wird chronologisch ab 1000 aus den verbleibenden Spielen neu berechnet,
nicht durch Subtraktion historischer Elo-Deltas. Eine Zeitbegrenzung ersetzt
den Jahresfilter. Die Regeln gelten auch für Live-Ranking und Elo-Vorschau.
Die Berechnung erfolgt beim Laden/Aktualisieren; es gibt keinen Serverjob.

Löschen setzt eine dauerhafte Löschmarkierung. Dadurch verschwindet die
Rangliste aus Auswahl und Live-Anzeige; Turniere, Ergebnisse, Statistiken
und historische Ranglistenzuordnungen bleiben unverändert. Es erfolgt keine
automatische Zuordnung zu einer anderen Rangliste.

Migration: `20261008180000_ranking_rules.sql` (am 08.10.2026 ausgeführt).
Versionierte Speicherung in `community_ranking_settings` und lokalem
Cache `ranking-settings-v1`. Fehlende Einstellungszeilen bedeuten unbegrenzte
Gültigkeit und keine Löschmarkierung. Nur Mitglieder lesen Einstellungen;
nur Mitglieder mit Verwaltungsrecht schreiben sie (RLS).
