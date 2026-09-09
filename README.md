# Dart Turnierverwaltung

Flutter-App zur Verwaltung von Dart-Turnieren.

## Projektstruktur

Die App wird schrittweise modularisiert, damit spaetere Features sauber erweitert werden koennen. Die verbindlichen Hinweise fuer kuenftige Codex-Sitzungen stehen in [AGENTS.md](AGENTS.md).

Die aktuelle Architektur-Notiz und der empfohlene Refactor-Plan stehen in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Entwicklung

```powershell
flutter analyze
flutter test
```

## Online-Communities konfigurieren

Communities verwenden ein Supabase-Projekt. Die Zugangsdaten werden nicht im
Quellcode hinterlegt. Beim lokalen Start muessen deshalb die URL des aktiven
Projekts und dessen Publishable/Anon-Key uebergeben werden:

```powershell
flutter run --dart-define=SUPABASE_URL=https://<projekt-ref>.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

Ohne diese Angaben laeuft die App im lokalen Account-Modus; Communities sind
dann bewusst nicht verfuegbar. So fuehrt eine geloeschte oder falsche
Supabase-Hostadresse nicht zu endlosem Laden.

