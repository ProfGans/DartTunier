# Turniertester

Im Projektordner `Turniertester.cmd` doppelklicken. Flutter muss installiert und im PATH verfügbar sein. Nach dem Lauf öffnet sich der Kontrollbericht im Browser.

Ohne automatisches Öffnen:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool\run_tournament_audit.ps1 -NoOpen
```

## Ausgabe

- `build/tournament_audit/index.html`: Gesamtergebnis und Prüfprotokolle.
- `build/tournament_audit/simulation.html`: durchsuchbare Szenarien, Ergebnisse, Weiterkommende und vollständige Matchbäume.
- `build/tournament_audit/simulation.json`: dieselben Simulationsdaten zur weiteren Auswertung.
- `build/tournament_simulation/tournament_trees.log`: bestehender Matrix-Kontrollbericht.

Jedes Szenario aus `test/support/tournament_simulation_scenarios.dart` läuft mit der Standard-Spielstärkereihenfolge sowie den reproduzierbaren Seeds 7 und 42. Fehler werden je Szenario gesammelt, damit der übrige Bericht trotzdem entsteht. Ergänzende Tests prüfen unter anderem Vorschläge, Boardplanung, Freilose und sichere Qualifikation.

Die Simulation ruft dieselbe produktive Laufzeit für Aufbau, Freilose, Ergebnisweitergabe, Tabellen und Qualifikation auf. Nur Spielergebnisse werden vorgegeben. Sie ist kein vollständiges Durchklicken der App. Fehler der produktiven Laufzeit erscheinen ausdrücklich als fehlgeschlagene Szenarien. Sie verändert keine gespeicherten Benutzerturniere. Berichte werden bei jedem Lauf überschrieben. Exitcode 1 kann auch durch Analysehinweise entstehen; deren Ursache steht getrennt im Analyseprotokoll.
