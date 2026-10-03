# Turnierformfinder

Der Dialog verwendet `ExpandedFormatPlanner`. Die Suche umfasst Jeder gegen jeden,
einfache, doppelte und dreifache KO-Etappen, Kratzer mit 2 bis zur gewählten maximalen
Lebenszahl (höchstens 10), sowie Mini-KO-, Mini-Doppel-KO- und Mini-Triple-KO-Gruppen.
Sie kombiniert diese Modi in bis zu vier Etappen (Standard: drei). Zwischenetappen
reduzieren die Teilnehmerzahl; KO-Vorrunden halbieren sie, Gruppen übernehmen die
eingestellte Qualifikation je Gruppe. Jede Gruppe enthält mindestens drei Spieler.

Die maximale Gruppenzahl ist eine Obergrenze je Etappe. Nur die separate Option
„Gruppenphase erforderlich“ schließt Turniere ohne Gruppen aus. Die übrigen
Vorgaben (Mindestspiele, Zeitfenster/Wunschzeit, Sets und Unentschieden) bleiben aktiv.
Unentschieden sind auf Jeder-gegen-jeden-Etappen beschränkt. KO benötigt Sieger.

Die Suche ist bewusst begrenzt: Pro Tiefe werden die 48 am besten bewerteten
Zwischenaufbauten weiter untersucht. Sie ist keine vollständige Enumeration aller
möglichen Turniere. Pro Aufbau bleibt das am besten passende untersuchte Spielformat.
Untersucht werden Bo1 bis Bo101, optional Sets, gleiche oder schrittweise längere
Leg-Distanzen sowie eine längere Set-Distanz oder 501 statt 301 in der letzten Etappe.
Die bestehende Regel für maximal einen Best-of-Schritt pro Etappe bleibt verbindlich.

Aufbauten werden über `ConfigurationDurationEstimator` und die Produktions-Runtime
simuliert, nicht mit einer zweiten KO-Engine. Die Boardbelegung wird einmal je
Etappenaufbau berechnet und mit der jeweiligen Matchdauer skaliert. Eine Folgeetappe
wird bei der Simulation von KO-Vorrunden berücksichtigt, damit die Vorrunde bei der
benötigten Qualifikantenzahl endet. Die Mindestspielzahl ist eine sichere Untergrenze.
Spielanzahl und Dauer bei Mehrfach-KO/Kratzer sind repräsentative Schätzungen und
können vom Ergebnisverlauf abweichen. Freilose werden nicht als Matches gezählt.

Vorschläge enthalten vollständige `TournamentStage`-Konfigurationen. Die Übernahme
bewahrt Qualifikationen, Leben, Finalregel und Spielformate und bleibt bearbeitbar.
Bei bereits ausgewählten Spielern muss deren Zahl mit dem Finder übereinstimmen.

Die Modusliste im Finder erlaubt die unabhängige Auswahl von Einfach-KO, Doppel-KO, Triple-KO, Kratzer sowie Gruppen mit Jeder-gegen-jeden, Mini-KO, Mini-Doppel-KO und Mini-Triple-KO. Standardmäßig sind alle aktiv. Der Filter gilt für jede Etappe, auch in Kombinationen. Eine leere Auswahl oder eine erforderliche Gruppenphase ohne aktivierte Gruppen-Spielart sperrt die Berechnung mit einem Hinweis. Änderungen verwerfen bestehende Vorschläge.
