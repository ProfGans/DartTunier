# Turnierspiele auf Gruppengeräten

## Turniere aus dem Hauptmenü

Die Gerätezuweisung funktioniert auch bei lokalen Turnieren ohne Community.
Im Hauptmenü ein Turnier öffnen und in der Turnieransicht **Boards auf Geräte
übertragen** wählen. Dort können aktive Geräte im selben Netzwerk je Board
gekoppelt werden. Dafür sind weder Account noch Community-Mitgliedschaft nötig.
Scorerstart, Ergebnisrückgabe und gespeicherte Aufnahmen verwenden denselben
Ablauf wie Community-Turniere. Die Ergebnisse bleiben bei lokalen Turnieren lokal.

## Community-Turniere

1. Zielgerät mit einem Account der Community als Gerät hinzufügen und den Gerätemodus einschalten.
2. Beide Geräte müssen im selben erreichbaren lokalen Netzwerk sein.
3. In der Community beim Turnier **Geräte zuteilen** öffnen. Mit den Rechten
   **Geräte zuteilen** und **Turniere leiten** öffnet sich die Turnierleitung mit Gerätezuweisung.
4. Für jedes Board ein aktives Gruppengerät auswählen und die Kopplungsanfrage dort bestätigen.
5. Zur Turnieransicht zurückkehren und das geplante Spiel am Board starten.
   Der Geräte-Scorer öffnet sich automatisch mit Namen und strukturierten X01-Regeln.

Startpunktzahl, Double-In, Single-/Double-/Master-Out, Best-of-Legs und
Best-of-Sets werden übertragen. Gerade Leg-Anzahlen unterstützen Unentschieden
(zum Beispiel 2:2 bei vier Legs); ein entscheidender Sieg beendet das Spiel früher.
Ergebnisrückgabe, Statistiken und Elo behandeln ein Remis als abgeschlossenes Spiel.
Cricket wird als noch nicht unterstützt angezeigt.
Ohne Turnierleitungsrecht dient die Gerätezuweisung weiterhin nur als Anzeige.

Nach Spielende sichert das Gerät das Ergebnis einschließlich sämtlicher
Scorer-Aufnahmen lokal. Über die signierte LAN-Verbindung fragt die Leitung
das Ergebnis erneut ab, bis es übernommen wurde. Wiederholte Antworten werden
über die Spielzuweisung erkannt. Veränderte Paarungen, Spielformate oder neu
gestartete Begegnungen erhalten eine andere Identität; alte Ergebnisse werden
abgelehnt. Die Leitung übernimmt das Ergebnis in die vorhandene Turnierlogik.

Die Community-Statistik berechnet Average, 180er und Checkoutquote aus den
übertragenen Aufnahmen. Ausstehende Community-Turnieränderungen werden bei
laufender App alle zwei Minuten und beim Abschluss sofort zu Supabase
synchronisiert; manuelle Synchronisierung bleibt möglich. Es gibt keine
Cloud-Abfrage pro Wurf. Die lokale Kopie bleibt auch nach dem Upload erhalten.

Die Turnieransicht muss für die Verbindung geöffnet bleiben; App und Gerätemodus
müssen auf dem Empfänger laufen. Dies ist keine Betriebssystem-Pushbenachrichtigung
für eine geschlossene App. Ein laufendes Spiel bleibt bei Layoutwechseln und
beim Wechsel zur Geräteverwaltung im Speicher erhalten. Ein Neustart während
eines noch laufenden Spiels stellt die einzelnen Eingaben bisher nicht wieder her;
fertige Ergebnisse sind lokal gesichert und werden bei derselben Zuweisung erneut angeboten.

## Speicherung und Kompatibilität

Board-Protokoll Version 2 ergänzt die optionale Spielidentität und das Format.
Der neue Empfänger akzeptiert Version 1 weiterhin als Anzeige; beide Apps müssen
für den Scorer aktualisiert werden. Antworten mit Ergebnissen sind separat
signiert. Die lokale Turnierspeicherung nutzt Version 8; ältere Daten bis Version 7
werden ohne Ergebnisstatistik gelesen und beim Schreiben mit Versionsbackup migriert.
`GroupMatch.deviceResult` ist optional. Dafür wird keine neue Supabase-Tabelle benötigt.
Scorer-Statistiken verwenden Version 2 mit dem Feld `isDraw`; Version 1 bleibt
lesbar und wird ohne Remis-Markierung übernommen.

## Prüfungen

- `test/device_scorer_test.dart`: Formatübernahme, signierte HTTP-Rückgabe,
  wiederholte Abfragen, Ergebniszuordnung, Persistenz und Statistik.
- `test/device_scorer_widget_test.dart`: Scorerzustand bei erneutem Aufbau und
  360×800, 800×600 sowie 1440×900 mit zweifacher Schriftgröße.
- Bestehende Geräte-, Statistik-, Speicher-, Layout- und Turniermatrix-Tests.

Ein physischer Test zwischen Windows und Android steht noch aus.
