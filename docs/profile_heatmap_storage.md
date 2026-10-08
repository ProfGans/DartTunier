# Profil-Heatmaps

## Speicherung

Heatmaps speichern Rohdaten in Millimetern, keine Bilddateien. So bleiben Filter, Gruppierung, Zielanalyse und spätere Darstellungen möglich. Der geräteweite Scorer-Verlauf liegt in SQLite (`heatmap_sessions`); alte SharedPreferences-Daten bleiben bei der Migration als Sicherung erhalten. Spiele werden anhand ihrer Sitzungs-ID ersetzt, nicht bei jedem Dart erneut angehängt.

SQLite-Schema 5 ergänzt `profile_heatmaps`: ein Datensatz pro Account und Sitzung mit dauerhafter Upload-Markierung. Nur Treffer des zugeordneten Spielerindex werden übernommen. Namen bestimmen keine Eigentümerschaft. Bestehende Sitzungen werden aus der gespeicherten Account-Spielhistorie übernommen, ohne neuere Profilstände zu überschreiben. Ein Fehler im alten Archiv verhindert nicht das Laden bereits gespeicherter Profil-Heatmaps.

Der private Supabase-Abgleich verwendet dieselbe Account-/Sitzungs-ID. Die Migration `202610080001_profile_heatmaps.sql` wurde am 08.10.2026 im vorhandenen Projekt ausgeführt; die Datenbank bestätigt aktivierte Row Level Security und vier Eigentümerregeln. Öffentliches Lesen und Community-Freigaben sind nicht enthalten. Ein Abgleich erfolgt beim Verlassen des Scorers und beim Laden/Aktualisieren des eigenen Profils.

Offline bleiben Änderungen in SQLite ausstehend und werden später erneut übertragen. Bestätigt wird nur genau die hochgeladene Version: Änderungen während eines Uploads behalten ihre Markierung und werden nicht von einem älteren Download überschrieben. Account-Wechsel unterbrechen den Abgleich. Vollständig rückgängig gemachte Treffer werden als leere Sitzung gespeichert und übertragen, damit ältere Cloud-Treffer nicht wieder erscheinen. Es gibt keine automatische Löschung alter Spiele.

## Daten und Auswertung

Sitzungs-Payload-Version 2 ergänzt pro lokalisiertem Dart ein optionales, vor dem Wurf ausdrücklich gewähltes Ziel, Dartposition 1–3, Aufnahme im Leg und UTC-Wurfzeit. Version 1 bleibt lesbar. Alte Ziele und Zeiten bleiben unbekannt; beim Wiedergeben alter Aktionen entstehen keine erfundenen Wurfzeiten. Das gewählte Ziel wird beim Spieler- oder Legwechsel zurückgesetzt.

Die Detailansicht bietet Scoring, Checkout, Training und Entwicklung sowie Filter nach Ziel, getroffenem Feld, Dartposition, Aufnahme, Sitzung, Leg, Spieler, Zeitraum und Schätzungen. „Training“ bedeutet hier Würfe mit ausdrücklich erfasstem Ziel, auch aus normalen Spielen. „Entwicklung“ vergleicht zwei aufeinanderfolgende 28-Tage-Zeiträume innerhalb der aktiven Filter. Ohne individuelle Zeit wird das Sitzungsdatum verwendet.

Zielsegment-Anteile verwenden ausschließlich lokalisierte Würfe mit bekanntem Ziel. Nicht lokalisierte Fehlwürfe fehlen, daher sind diese Werte keine vollständige Checkoutquote. Der Lieblingsdoppel-Bereich wird hervorgehoben. Gruppierung (RMS um den Trefferschwerpunkt), Nachbarfelder und Abstand zur geometrischen Segmentmitte werden getrennt ausgewiesen. Single- und äußere Bull-Felder erhalten keine erfundene eindeutige Zielmitte.

## Grenzen und Prüfung

Gespeichert werden ganze Sitzungs-Payloads. Das ist für normale Spielhistorien sinnvoll; bei sehr großen Archiven wären einzelne Dart-Zeilen, gezielte SQL-Zeitraumabfragen und inkrementelle Übertragung der nächste Ausbauschritt. Zwei Geräte, die dieselbe Sitzung gleichzeitig ändern, verwenden den zuletzt hochgeladenen Stand; eine verteilte Zusammenführung ist nicht implementiert. Community-Ergebnisse ohne freigegebene Positionsdaten erzeugen keine Heatmap.

Repository-Tests prüfen Offline-Neustart, Kontotrennung, leere Rückgängig-Stände und Änderungen während eines Uploads. Scorer-Tests prüfen Ziel-/Zeit-Replay und alte Aktionen. Responsive Tests prüfen 360×800, 800×600 und 1440×900 einschließlich 200 Prozent Text. Gerenderte Ansichten werden unter `build/heatmap_previews` abgelegt. Ein Abgleich zwischen zwei echten angemeldeten Geräten wurde nicht durchgeführt.
