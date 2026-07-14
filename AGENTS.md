# Codex project instructions

Dieses Projekt soll langfristig modular weiterentwickelt werden. Bitte diese Datei zu Beginn jeder Codex-Sitzung lesen und bei Aenderungen an der App beachten.

## Zielbild

- Die App ist eine Dart-/Flutter-Turnierverwaltung, die spaeter weitere Bereiche und Features bekommen soll.
- Neue Features sollen als eigene Module/Feature-Bereiche angelegt werden, nicht als weitere grosse Klassen oder Sammeldateien.
- Bestehende Logik soll Schritt fuer Schritt aus `part`-Dateien in echte Dart-Libraries mit expliziten Imports ueberfuehrt werden.

## Architekturregeln

- `main.dart` soll nur Bootstrap bleiben: `runApp`, App-Root importieren, keine Fachlogik.
- UI, Domain-Modelle, Turnierlogik und Persistenz trennen.
- Fachlogik zuerst in testbare Services/Engines legen, Widgets sollen moeglichst wenig Berechnung enthalten.
- Neue Turniermodi gehoeren in eigene Mode-/Engine-Dateien mit klarer Schnittstelle.
- Speicherung immer versioniert halten und Migrationen einplanen, sobald das JSON-Schema geaendert wird.
- Grosse Widgets in kleinere, thematisch benannte Widgets zerlegen, aber nur entlang echter Verantwortlichkeiten.
- Bestehende Tests beim Refactor erhalten und fuer neue Fachlogik bevorzugt Unit-Tests ergaenzen.

## Entwicklungstester

- Bei Aenderungen an Turnierlogik, Brackets, Weiterkommen, Gruppen-/KO-Modi oder Ergebnisweitergabe den Entwicklungstester selbststaendig ausfuehren:
  `flutter analyze`
  `flutter test test\tournament_simulation_matrix_test.dart`
- Diese beiden Befehle sind der verbindliche Entwicklungstester. Wrapper-Skripte sind optional, aber die direkten Befehle sind in der Codex-Umgebung am zuverlaessigsten.
- Der Matrix-Test schreibt zur Nachvollziehbarkeit einen Turnierbaum-/Matchbaum-Report nach `build/tournament_simulation/tournament_trees.log`.
- Neue Turniermodi oder wichtige Sonderfaelle muessen in `test/support/tournament_simulation_scenarios.dart` als Szenario ergaenzt werden.
- Wenn der Entwicklungstester rot wird, erst die Ursache beheben oder den verbleibenden Fehler im Abschluss klar benennen.

## Gewuenschte Zielstruktur

```text
lib/
  main.dart
  app/
    dart_tournament_app.dart
    navigation/
  features/
    home/
    tournaments/
      data/
      domain/
      application/
      presentation/
      modes/
        groups/
        knockout/
        double_ko/
        triple_ko/
  shared/
    widgets/
    utils/
```

## Aktueller Zustand

- `main.dart` ist Bootstrap und importiert `lib/app/dart_tournament_app.dart`.
- App-Shell und Theme liegen in `lib/app/`.
- Domain-Modelle, Storage, erste Application-Controller und eine erste testbare Tournament-Engine liegen unter `lib/features/tournaments/`.
- Viele UI- und Mode-Dateien liegen bereits in Feature-Ordnern, sind aber technisch noch ueber `part of 'tournament_workspace.dart'` gekoppelt.
- Erste Run-Presentation-Bausteine sind bereits echte Libraries: `presentation/widgets/run/stage_controls.dart`, `presentation/widgets/run/stage_play_order_section.dart`, `presentation/widgets/run/result_entry.dart`, `presentation/widgets/run/stage_surface.dart`, `presentation/widgets/run/standings_table.dart`, `presentation/widgets/run/group_run_section.dart`, `presentation/widgets/run/group_stage_run_section.dart`, `presentation/widgets/run/mini_knockout_group_run_section.dart`, `presentation/widgets/run/best_of_comparison_table.dart`, `presentation/widgets/run/knockout_run_section.dart` und `presentation/models/match_result.dart`.
- Erste Creation-Presentation-Bausteine sind echte Libraries: `presentation/widgets/creation/stage_setup_widgets.dart` enthaelt kleine Setup-/Preview-Widgets fuer Spieler-Umbenennen, Gruppengroessen, Gruppenspieltyp, Round-Robin-Wiederholungen, Matchzaehlung, Tie-Breaker und Qualifikations-Auswahl.
- `lib/tournament_workspace.dart` ist die aktuelle Uebergangs-Library fuer die alten `part`-Dateien.
- Das Run-Bracket liegt bewusst als zusammenhaengendes Modul unter `features/tournaments/presentation/widgets/run/brackets/knockout_bracket_view.dart`; nicht jede Bracket-Hilfsklasse einzeln auslagern, solange die Datei fachlich zusammenhaengt.
- Die groessten verbleibenden Dateien sind aktuell `features/tournaments/presentation/widgets/tournament_creation_widgets.dart`, `features/tournaments/presentation/pages/tournament_creation_page.dart`, `features/tournaments/presentation/pages/tournament_run_page.dart` und das Bracket-Modul.
- Der naechste sinnvolle Refactor ist, UI-Parts schrittweise in echte Libraries zu ueberfuehren und private `_...` Cross-File-Abhaengigkeiten aufzuloesen.

## Refactor-Reihenfolge

1. Weitere Turnier-Regeln und Mode-Engines aus den verbleibenden Parts in `domain/engines` oder `modes/*` ueberfuehren.
2. Creation- und Run-State weiter aus den Seiten in Application-Controller ziehen.
3. Grosse Presentation-Dateien in kleinere, echte Widget-Libraries aufteilen. Begonnen bei Run-Controls, MatchResult, Ergebnis-Erfassung und Creation-Setup-/Qualifikations-Widgets.
4. Private `_...` Widgets/Helfer, die dateiuebergreifend gebraucht werden, bewusst public machen oder in passende Libraries verschieben.
5. `tournament_workspace.dart` loeschen, sobald keine `part`-Dateien mehr existieren.
