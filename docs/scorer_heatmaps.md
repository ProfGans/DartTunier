# Autoscoring-Heatmaps

Im Scorer sowie im Statistik-Cockpit führt „Autoscoring-Heatmaps“ zum lokalen
Archiv. Das Board-Symbol im laufenden Match öffnet die aktuelle Spielverteilung.
Filter: Spieler bzw. Doppelpartner, Spiel, Leg, Zeitraum, Schätzungen und
Checkoutversuche. Feldhäufigkeiten, T20-/Doppel-/Triple-Anteile, Schwerpunkt und
RMS-Streuung ergänzen die Grafik. Die relative Farbskala gilt nur für die jeweils
ausgewählte Verteilung; Streuung ist keine Messung der Zielgenauigkeit.

## Erfassung und Speicherung

- Tatsächliche Positionen in Millimetern, Bull als Ursprung, negative Y-Achse oben.
- Kamera-Schätzungen und manuell korrigierte Positionen sind gekennzeichnet.
- Bestätigung durch Herausziehen speichert die Aufnahme. Vorschauen werden bei
  Korrekturen ersetzt, nicht zusätzlich gezählt. Rückgängig korrigiert das Archiv.
- Überwürfe bleiben physische Treffer. Unbekannte Positionen, Bouncer, manuelle
  Summeneingaben und Bots erzeugen keine erfundenen Heatmap-Punkte.
- Doppelpartner werden entsprechend ihrer jeweiligen Aufnahme zugeordnet.
- Archiv in SharedPreferences: `scorer_heatmap_archive_v1`, Schema 1; Upsert über
  die stabile Sitzungs-ID. Auch Gastspiele werden erfasst. Das Archiv ist lokal
  auf diesem Gerät und wird derzeit nicht mit Supabase synchronisiert.
- Namensfilter sind lokale Anzeigenamen; gleichnamige Personen werden zusammen
  ausgewertet. Das ist keine kontoübergreifende Identitätszuordnung.
- Spielstand-Schema 2 speichert optionale Positionsdaten im Aktionsverlauf.
  Schema 1 bleibt lesbar; alte Spiele erhalten keine nachträglich erzeugten Punkte.

Tests: `test/scorer_heatmap_test.dart`, `test/scorer_camera_panel_test.dart` und
`test/scorer_autoscoring_test.dart` sichern Speicherung, Vorschau/Bestätigung,
Korrekturen, Replay, Undo, Teams und Layouts mit 200 Prozent Schrift ab.
