# Autoscoring bei Desktop-Fokusverlust und minimiertem Fenster

Aktive Desktop-Erkennung wird bei `inactive`, `hidden` oder `paused` nicht mehr
angehalten. Das betrifft sowohl die Kamera-Arbeitsfläche im Autoscorer als auch
das kompakte Kamerapanel im normalen Scorer. Kamerapolling, Trefferzählung,
Herauszieh-Erkennung und Audio laufen über Timer und Modellereignisse weiter,
auch wenn Flutter währenddessen keine UI-Frames zeichnet.

Die gemeinsame Entscheidung liegt in
`application/autoscore_lifecycle_policy.dart`. `detached` beendet weiterhin die
Erkennung. Auf Android/iOS bleibt der Hintergrund-/Fokusverlust eine Pause;
dieser Desktop-Fix implementiert keinen mobilen Kamera-Hintergrunddienst.
Die App muss geöffnet bleiben; ein geschlossenes Programm oder ein PC im
Ruhezustand ist kein Hintergrundbetrieb dieses Features.

## Spielzustand ohne sichtbare UI

`ScorerCameraPanel` erhält optional eine direkte Eingabefreigabe, einen aktuellen
Darts-restlich-Provider und einen `Listenable` des Spielmodells. Die lokale
`ScorerMatchPage` verbindet diese mit ihrem Controller. Spieler-/Botwechsel,
Spielende und die noch verfügbaren Darts werden so ohne UI-Neuaufbau geprüft.
Ein Botzug pausiert die Kameraabfrage, der nächste menschliche Zug reaktiviert
sie mit derselben Referenz. Kalibrierung und steckende Pfeile werden durch den
Fokuswechsel nicht verworfen. Beim Schließen des Kamerabereichs oder Beenden
bleibt die Eingabe gesperrt. Manuelle Positionskorrekturen pausieren die Erkennung
weiterhin für die Dauer der Eingabe.

## Prüfung

- Neue Lifecycle-Unit-Tests für Windows, Linux, macOS und Android/iOS.
- Kamera-Seite: Desktop bleibt bei Ausblenden/Minimieren aktiv, mobile Seite stoppt.
- Kompaktes Panel: drei Würfe und Herausziehen im Zustand `paused`, während keine
  UI-Neuaufbauten stattfinden. 60 Punkte werden übernommen und drei richtige Würfe
  dem Setup zugeordnet. Botstart sperrt die Eingabe, Botende reaktiviert die Kamera
  mit neuer verbleibender Dartzahl. Rückkehr ins Fenster startet nicht doppelt.
- 48 Hintergrund-/Scorer-/Caller-/Kamera-Widgettests bestanden.
- 63 weitere Hintergrund-/Controller-/Herauszieh-/Scorer- und gemeinsame adaptive
  Layout-/Seitenfälle bestanden; beide Testsuiten enthalten einige gleiche Fälle.
- `flutter analyze --no-pub`: keine Befunde.
- Keine UI-Gestaltung verändert; Layoutmatrix 360/800/1440 Pixel einschließlich
  großer Schrift bestanden. Livebetrieb mit echten USB-Kameras und minimiertem
  Fenster wurde in dieser Änderung nicht geprüft.

Logs: `build/autoscore_analysis/background_tests.log`, `background_regressions.log`,
`background_analyze.log`, `background_release_build.log`.
