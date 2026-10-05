# Autoscorer-Setups und Genauigkeit

Der Menüeintrag „Autoscorer“ ersetzt den bisherigen „Autoscore-Tester“.
Die Einstiegsseite bietet die Auswahl eines aktuellen Setups, das Anlegen und
Umbenennen benannter Setups sowie dessen dauerhaft gespeicherte Statistik.
Über „Kameras, Kalibrierung und Erkennung öffnen“ bleiben Kameraansichten,
automatische Kalibrierung, flache Boardansicht, Korrekturen, fehlende Würfe und
Diagnose-Exporte erreichbar.

## Gespeicherte Einstellungen

- Kamerageräte und deren Reihenfolge, bevorzugt über Gerätename und bei gleichen
  Namen über deren Vorkommen. Ohne gespeicherte Auswahl bleiben USB-Kameras Standard.
- Caller, Treffer-/Bouncer-Sounds und Lautstärke.
- Das bisherige automatische Starten beim Öffnen einer Partie bleibt eine globale
  Einstellung; die Kamera- und Audioauswahl verwendet das aktuelle Setup.
- Ein neues Setup übernimmt zunächst die Kamera-/Audioeinstellungen des aktuellen
  Setups und beginnt mit eigenen leeren Statistikzählern.
- Kalibrierungen werden bei jeder Verbindung frisch geprüft; ein Setupname ersetzt
  keine neue Kalibrierung nach Boarddrehung oder Umbau.

## Statistikregeln

Jeder automatisch gezählte Wurf und jeder in der Kamera-Arbeitsfläche nachgemeldete
Wurf gehört fest zu dem beim Erkennen/Melden aktiven Setup. Spätere Setupwechsel
oder Umbenennungen verschieben diese Zuordnung nicht.

Unkorrigierte Würfe werden beim automatischen oder bestätigten Herausziehen als
richtig bewertet. Eine Korrektur zählt stets als falsch, auch wenn sie den Wert
nicht verändert. Mehrere Korrekturen desselben Wurfs erhöhen den Fehlerzähler nicht
mehrfach. Eine spätere Korrektur eines zuvor bestätigten Treffers zieht ihn aus dem
Richtig-Zähler ab und fügt ihn zum Fehlerzähler hinzu. Fehlende, manuell nachgemeldete
Würfe zählen als Fehler. Diese Regeln gelten auch für die Boardkorrektur im normalen
Scorer. Manuell ohne Kameras eingegebene Würfe gehören nicht zu dieser Statistik.

Genauigkeit = richtige / (richtige + falsche) Würfe * 100. Noch ungeprüfte Würfe
werden gesondert ausgewiesen. Die Prozentzahl beruht auf den Benutzerkorrekturen
und ist keine unabhängige Messung der tatsächlichen Erkennungsgenauigkeit.
Zusätzlich werden Gesamtwürfe, Schätzungen, nachgemeldete Würfe und Bouncer gezählt.
Nicht abgeschlossene Aufnahmen bleiben ungeprüft, wenn die Erkennungsseite beendet
wird. Die bisherige lokale Sitzungshistorie wird nicht als globale Historie gespeichert.

## Architektur und Persistenz

`domain/autoscore_setup.dart`: Setupmodell, Statistikwerte und feste Wurfzuordnung.
`data/autoscore_setup_store.dart`: gemeinsame Setupauswahl und sequenziell gespeicherte
JSON-Snapshots in SharedPreferences (`autoscoring.setups.v1`, Schema version 1).
Ohne alte Daten wird „Standard-Setup“ angelegt. Unbekannte oder ungültige Schema-
Versionen werden nicht überschrieben; die UI zeigt den Ladefehler. Bestehende Kamera-
Kalibrierungen und globale Startpräferenz bleiben mit ihren bisherigen Schemas erhalten.

Die lokale Sitzung des Kamera-Testbereichs bleibt im DemoController; dieser übergibt
Bewertungen an den Store. Der normale `ScorerCameraPanel` nutzt dieselben Zählregeln.
Diagnosen erhalten die Setup-ID (im Scorer zusätzlich den damaligen Setupnamen).
Neue dauerhafte Statistiken werden ab Verwendung dieser Version gesammelt; die zuvor
nur im Arbeitsspeicher vorhandenen Sitzungsergebnisse lassen sich nicht nachträglich
rekonstruieren.

## Prüfung

- 40 gezielte Setup-/Persistenz-/Menü-/Audio-/Kamera-/Genauigkeitstests bestanden.
- 31 weitere Kamera-Scorer- und gemeinsame Layout-/Seitenregressionen bestanden;
  die neue Seite wurde in `responsive_pages_test.dart` ergänzt.
- `flutter analyze --no-pub`: keine Befunde.
- Layouts 360x800, 800x600 und 1440x900, jeweils normale und 200% Schrift;
  Setup anlegen und auswählen sowie Dialoge mit langen deutschen Namen geprüft.
- Gerenderte mobile und Desktop-Vorschauen angesehen:
  `build/layout_previews/autoscorer_setups_360.png`, `_800.png`, `_1440.png`.
- Keine physische Smartphone- oder USB-Kamera-Sichtprüfung in dieser Änderung.

Logs: `build/autoscore_analysis/setups_final_tests.log`, `setups_regressions.log`,
`setups_analyze.log`, `setups_release_build.log`.
