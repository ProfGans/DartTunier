# Bots in Turnieren

In der normalen und Community-Turniererstellung führt „Bots hinzufügen“ zum
Bot-Dialog. Einzeln werden Name und Theo-Ziel-Average gewählt. „Mehrere Bots“
erzeugt 1–128 Teilnehmer mit zufällig verteilten Ziel-Averages im Von–bis-Bereich.
„Bot-Stärke“ am Teilnehmer bearbeitet dessen Konfiguration vor dem Turnierstart.
Die tatsächlich gespielten Averages können vom Zielwert abweichen.

Die vorhandene TheoAverageService-Auflösung erzeugt das Scorer-Profil. Zielwert
und aufgelöste Wurfparameter werden zusammen gespeichert, damit ein Update oder
später geänderte globale Einstellungen bestehende Bots nicht verändern.
Turnier-Speicherversion 16 ergänzt das optionale Bot-Profil; frühere Teilnehmer
ohne dieses Feld bleiben Menschen. Geräteprotokoll 4 überträgt beide Bot-Profile
an den Scorer und liest weiterhin Protokollversion 1–3.

Im Geräte-Scorer werden Bots mit der bestehenden Wurfsimulation gespielt, auch
Bot gegen Bot. Ergebnisse und Aufnahmen gelangen über den normalen Ergebnisimport
zurück ins Turnier. Es werden keine Ergebnisse allein beim Hinzufügen erfunden.
Bots besitzen kein Benutzerkonto und werden nicht mit Community-Mitgliedern
gleichen Namens für Elo verwechselt. Bots nehmen derzeit einzeln teil; Teams
mit Bots sind noch nicht unterstützt.

Bei geöffneter Turnierleitung werden Bot-gegen-Bot-Spiele automatisch simuliert,
sobald alle Begegnungen mit Menschen in derselben oder einer früheren Runde
der aktiven Etappe abgeschlossen sind. Die Sperre gilt über alle Gruppen hinweg.
Unbekannte Teilnehmer halten die Runde ebenfalls zurück. Reine Bot-Runden laufen
direkt; anschließend verwendet die App ihre normale Weiterkommenslogik.
Bereits auf einem Gerät gestartete Spiele bleiben beim Geräte-Scorer.

Die Simulation nutzt ScorerController und die gespeicherten Theo-Stärkeeinstellungen,
einschließlich Legs, Sets und Checkout-Regeln. Nur Ergebnisse werden im
Turnierstand gespeichert; Bots erhalten keine Spielerprofile oder gespeicherten
Wurfstatistiken und erscheinen nicht in Statistik-Highlights. Bei Mensch gegen
Bot bleiben die Wurfstatistiken des Menschen erhalten. Alte Bot-Wurfstatistiken
werden beim Laden herausgefiltert und beim erneuten Speichern entfernt. Simulierte Spiele
bekommen keinen gemessenen Startzeitpunkt: Rechenzeit ist keine Matchdauer.
Die Prüfung erfolgt beim Öffnen, nach Ergebnissen und beim Etappenwechsel.

Speicherpunkte: Menschliche Änderungen werden vor der Simulation gespeichert. Jedes fertige Bot-Ergebnis und die anschließende Weitergabe werden vor der nächsten Simulation gesichert. Beim Zurückgehen oder Hauptmenü wartet die Turnieransicht auf den Schreibvorgang; bei Fehlern bleibt sie geöffnet. Beim Wechsel in den Hintergrund wird ebenfalls gespeichert. Laufende Berechnungen werden dann nicht übernommen, sondern beim erneuten Öffnen/Fortsetzen bei Bedarf wiederholt. Ein sofortiges Beenden durch das Betriebssystem kann keinen zusätzlichen asynchronen Schreibvorgang garantieren; deshalb werden Ergebnisse bereits während des Ablaufs gesichert.
