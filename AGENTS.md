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
- `lib/tournament_workspace.dart` ist die aktuelle Uebergangs-Library fuer die alten `part`-Dateien.
- Die groessten Dateien sind aktuell `features/tournaments/presentation/widgets/tournament_run_widgets.dart`, `features/tournaments/presentation/widgets/tournament_creation_widgets.dart`, `features/tournaments/presentation/pages/tournament_creation_page.dart` und `features/tournaments/presentation/pages/tournament_run_page.dart`.
- Der naechste sinnvolle Refactor ist, UI-Parts schrittweise in echte Libraries zu ueberfuehren und private `_...` Cross-File-Abhaengigkeiten aufzuloesen.

## Refactor-Reihenfolge

1. Weitere Turnier-Regeln und Mode-Engines aus den verbleibenden Parts in `domain/engines` oder `modes/*` ueberfuehren.
2. Creation- und Run-State weiter aus den Seiten in Application-Controller ziehen.
3. Grosse Presentation-Dateien in kleinere, echte Widget-Libraries aufteilen.
4. Private `_...` Widgets/Helfer, die dateiuebergreifend gebraucht werden, bewusst public machen oder in passende Libraries verschieben.
5. `tournament_workspace.dart` loeschen, sobald keine `part`-Dateien mehr existieren.
