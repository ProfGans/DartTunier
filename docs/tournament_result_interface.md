# Ergebnisschnittstelle v1

`TournamentResultReceiver` ist der gemeinsame, transportunabhängige Eingang
für externe Ergebnisquellen. Der vorhandene Geräte-Scorer verwendet ihn bereits.
Ein HTTP-, Datei-, Bluetooth- oder Anbieter-Adapter kann später dieselbe
`submit(Map<String, dynamic>)`-Methode aufrufen. Es wird hier noch kein neuer
öffentlicher Netzwerk-Endpunkt geöffnet.

## Spielzuweisung und Payload

Die Turnierleitung startet die Partie über den bestehenden
`OrderOfPlayController.start`. Danach liefert
`TournamentMatchAssignment.id(tournament, entry)` einen undurchsichtigen
Zuweisungsschlüssel. Diesen vollständig übernehmen, nicht selbst zusammensetzen.
Er enthält auch den Startzeitpunkt, die Paarung und das Spielformat. Nach Neustart
oder Änderung einer Partie muss eine neue Zuweisung bezogen werden.

```json
{
  "version": 1,
  "matchId": "<Zuweisungsschlüssel der gestarteten Partie>",
  "source": "externer-scorer",
  "legs": [2, 1],
  "sets": [0, 0]
}
```

Reihenfolge immer Heim/Gast entsprechend der Zuweisung. Bei Satzspielen sind
`legs` die gesamten gewonnenen Legs über alle Sätze, `sets` das Satzergebnis.
Bei reinen Leg-Spielen immer `[0, 0]` für Sätze. Nur abgeschlossene Ergebnisse
sind erlaubt; Gleichstand nur bei passendem Unentschieden-Format.

`statistics` ist optional. Wenn vorhanden, gilt das bestehende
`SavedScorerMatch`-Format (Version 1/2); Spieler, Startpunkte, Gewinner und
Legsumme werden geprüft. Ohne Aufnahmen entstehen keine erfundenen Averages.
Bot-Aufnahmen werden wie bisher vor dem Speichern entfernt.

## Einbindung

Eine Receiver-Instanz pro laufendem Turnier verwenden:

```dart
final receiver = TournamentResultReceiver(
  tournament: tournament,
  authorize: requireTournamentLead,
  save: saveTournamentProgress,
  advance: advanceProductionRuntime,
);
final receipt = await receiver.submit(payload);
```

`authorize` prüft bei jedem Aufruf die aktuelle Berechtigung und Verfügbarkeit
der Turnierleitung. Netzwerk-Adapter müssen zusätzlich ihre Quelle authentifizieren;
der Spielschlüssel und das optionale `source`-Feld sind keine Zugangsdaten.
`advance` verwendet die produktive Weitergabe (KO, Swiss, Gruppen, Bots), keine
eigene Turnierlogik. Die bestehende Turnierseite verdrahtet diese Callbacks bereits.

Anfragen laufen seriell. Das Ergebnis wird vor dem Fortschreiben gespeichert.
Scheitert dieser erste Schreibvorgang, werden die Ergebnisfelder zurückgesetzt.
Danach werden Turnierfortschritt und ein zweiter Speicherpunkt ausgeführt.
Erst nach erfolgreichem Abschluss erhält die Quelle `accepted` oder
`alreadyAccepted`. Bei einem Fehler denselben unveränderten Payload erneut
senden; ein nach dem ersten Speicherpunkt unterbrochener Fortschritt wird erneut
angestoßen. Die Callbacks müssen deshalb wiederholbar sein.

Identische Wiederholungen werden auch nach Wiederöffnung erkannt. Abweichende
Übertragungen zur selben Zuweisung werden abgelehnt, statt Ergebnisse oder
Statistiken zu überschreiben. Korrekturen bleiben Aufgabe der Turnierleitung.
Ungültiges Format erzeugt `FormatException`, ein veraltetes oder widersprüchliches
Ergebnis `StateError`; Berechtigungs-/Speicherfehler werden weitergegeben.

## Kompatibilität

Das Geräteprotokoll bleibt Version 1, seine bisherigen Match-IDs bleiben gleich.
`DeviceResultImporter` bleibt als Adapter erhalten und verlangt weiterhin
Scorer-Statistiken. Der gemeinsame Eingang erlaubt zusätzlich reine Ergebnisse.
Der vorhandene optionale JSON-Bereich `deviceResult` enthält aus Kompatibilität
auch Ergebnisse anderer Quellen; es werden keine bestehenden Spielstände
umgeschrieben und keine neuen Pflichtfelder im Speicherschema eingeführt.
