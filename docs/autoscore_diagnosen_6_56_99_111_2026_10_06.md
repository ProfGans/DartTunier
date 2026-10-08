# Diagnosen 6, 56, 99 und 111 vom 06.10.2026

Quelle: die vier ZIPs aus `Downloads/Neuer Ordner (8)`. Auswertung mit der aktuellen Kontaktpipeline und chronologischem Video-Replay, ohne Übernahme der Nutzerkorrektur in die Erkennung.

| Fall | Nutzerkorrektur | Aktueller Replay | Ergebnis |
| --- | --- | --- | --- |
| 6 | T20 | 5 | weiterhin falsch |
| 56 | T20 | 20 | weiterhin falsch |
| 99 | T1 | T18 | weiterhin falsch |
| 111 | 3 | 19 | weiterhin falsch |

Die Diagnosen enthalten bereits die Revision `contact-evidence-v2-2026-10-05`. Es handelt sich also nicht um Fehler, die nur von einer älteren App-Version stammen. Der erfolgreich abgeschlossene Replay-Test bestätigt die Ausführbarkeit, nicht die Richtigkeit der Scores. Diese vier ausgewählten Fehlerfälle sind keine repräsentative Genauigkeitsmessung.

## Befunde beim ersten übernommenen Treffer

**6:** Nur eine Kamera liefert lokale Kontaktunterstützung. Der Kandidatenvergleich hat ausschließlich den falschen Punkt (-39, -114) für die 5. Der manuell gesetzte Punkt für T20 liegt ungefähr 29,7 mm entfernt. Der richtige Kontakt fehlt schon in der Kandidatenerzeugung. Ein bloßer Mehrheitsentscheid oder eine Ringkorrektur kann das nicht lösen.

**56:** Der geschätzte Radius beträgt ungefähr 107,4 mm und liegt knapp außerhalb des Triple-Rings. Ein T20-Endpunkt bei (14,41, -102,13) ist vorhanden, wird jedoch nicht durch zwei unabhängige Endpunkte bestätigt. Die lokale Ringprüfung greift deshalb nicht ein. Der Kontaktvergleich bevorzugt weiterhin 20. Es wurde nur der Score korrigiert; ein unabhängiger tatsächlicher Kontaktpunkt fehlt.

**99:** Wieder nur ein Kandidat, diesmal T18 bei (46, -89); am Entscheidungsframe hat keine Kamera gleichzeitig ausreichende neue lokale Kontaktpixel und eine passende Achse. Der manuelle T1-Punkt liegt ungefähr 30,1 mm entfernt. Kamera 1 wurde ausdrücklich als verdeckt markiert. Diese Markierung ist ein brauchbares Verdeckungslabel, aber kein sichtbar markierter Spitzenkontakt. Die vorhandenen Bilder zeigen enge Gruppen und überlagerte Schäfte. Die richtige neue Spitze muss früher in der Bildverarbeitung von bestehenden Darts getrennt werden.

**111:** Der Punkt liegt nur ungefähr 4,3 mm von der manuellen Korrektur entfernt, überschreitet aber die Grenze 19/3. Der Kontaktvergleich bevorzugt bereits 3 bei (-19,28, 126,43), mit zwei unterstützenden Ansichten; der Abstand der internen Bewertungen beträgt nur 0,327. Dieser Vergleich läuft weiterhin beobachtend und verändert keine Wertung. Die aktive Segmentgrenzenprüfung hat dagegen nur eine vollständig unterstützende Kamera und lehnt die Änderung ab. Zwei Kamera-Endpunkte widersprechen sich deutlich. Die unterschiedliche Definition der Unterstützung in beiden Prüfungen muss vor einer Aktivierung vereinheitlicht und an den bisherigen Regressionen geprüft werden.

## Nächste Änderungen, abgeleitet aus diesen Fällen

1. Für enge Gruppen neue Bildänderungen und bestehende Dartmasken getrennt behandeln; Kandidaten aus der neu hinzugekommenen Spitze erzeugen. Fälle 6 und 99 benötigen neue Kandidaten, nicht nur eine andere Gewichtung vorhandener Kandidaten.
2. Bei Ringgrenzen tatsächliche lokale Ringkante und Endpunktunsicherheit gemeinsam auswerten. Fall 56 nicht pauschal auf Triple ziehen; benachbarte korrekte Single-Treffer müssen erhalten bleiben.
3. Für Segmentgrenzen die unterstützenden Kameras anhand derselben lokalen Kontaktbedingungen bestimmen. Fall 111 gemeinsam mit den alten Fällen 27 und 92 sowie korrekten Randtreffern prüfen, bevor der Kontaktvergleich eingreifen darf.
4. Weitere Originalbildmarkierungen sammeln: sichtbare Spitze und zwei Schaftpunkte je nutzbarer Kamera, verdeckte Kameras ausdrücklich markieren. Ein einzelnes Verdeckungslabel reicht nicht für ein trainiertes Kontaktmodell.

## Reproduzierbarkeit und Grenzen

Replay: `tool/autoscore_new_video_replay_test.dart` mit `VIDEO_REPLAY_CASES=6,56,99,111`, `VIDEO_REPLAY_ROOT=build/autoscore_analysis/new_6_56_99_111` und `VIDEO_REPLAY_OUTPUT=build/autoscore_analysis/new_6_56_99_111_results.json`.

Ergebnisse: `build/autoscore_analysis/new_6_56_99_111_results.json`; Protokoll: `build/autoscore_analysis/new_6_56_99_111_replay.log`. Original-Kameraübersichten wurden zusätzlich visuell geprüft. Die Untersuchung vergleicht den ersten übernommenen Treffer und die gespeicherten Live-Diagnosefelder, nicht nachträgliche Kandidaten späterer Bilder.

Der Replay rekonstruiert nicht sämtliche zuvor akzeptierten Würfe der ursprünglichen Sitzung. Verdeckungsbewertungen, die auf diesen historischen Positionen beruhen, können deshalb abweichen. Die manuell verschobenen Punkte sind Board-Korrekturen und keine unabhängig vermessenen Originalbildkoordinaten. Keine Live-Kameraprüfung und keine repräsentative Messung von 99,5 Prozent wurden durchgeführt. Die Erkennungslogik wurde in dieser Untersuchung nicht geändert.

## Umsetzung nach der Untersuchung

Die nachfolgende Änderung `measured-contact-retention-2026-10-06` behebt Fall 111 im chronologischen Replay (3 statt 19):

- Die Segmentprüfung verlangt, dass der vorgeschlagene Kontakt auf der richtigen Seite der gemessenen Kante liegt. Die alte Schätzung muss diese tatsächliche Kante nicht zusätzlich überqueren. Der Sicherheitsabstand beträgt mindestens 0,25 mm oder zweimal die gemessene Kantenstreuung. Unverändert erforderlich bleiben ein eindeutiger hochkonfidenter Endpunkt, ein naher Punkt im selben Ring und zwei Kameras mit passenden Achsen und neuen lokalen Kontaktpixeln.
- Ein so bestätigter Kontakt bleibt bei der begrenzten zeitlichen Auswahl erhalten, wenn die nächste Schätzung höchstens 4 mm entfernt liegt. Unabhängige konsistente Drei-Kamera-Unterstützung hat weiterhin Vorrang. Zurücksetzen löscht auch diese Zusatzinformation.
- Fall 111 ist mit Originalbildfolge als Regressionstest hinterlegt. Zusätzliche Tests schützen gegen entfernte Kontakte und das Überschreiben unabhängiger Drei-Kamera-Unterstützung.

57 gezielte Tests bestanden; anschließend acht Grenz-/Schutztests bestanden. Die 25 alten Replaypakete liefern dieselben Ergebnisse wie vor dieser Änderung. `flutter analyze` meldet ausschließlich den bereits bestehenden Hinweis in `test/manual_update_card_test.dart:35`.

Fälle 6, 56 und 99 bleiben falsch. Ein experimenteller Versuch mit zusätzlicher hochauflösender Neupixel-Maskierung für Ein-Kamera-Treffer erzeugte keinen ausreichend bestätigten richtigen Kontakt und erhöhte die Rechenzeit. Er wurde vollständig verworfen; keine zusätzliche Bildvollscan-Schleife wurde übernommen. Der neue Kontaktvergleich bleibt beobachtend. Die Änderung ist ein belegter Teilfortschritt, keine vollständige Lösung der engen Gruppen und keine Bestätigung des Genauigkeitsziels.

## Folgeänderung: sichtbare Spitzen und farbige Ringkanten

Revision `visible-endpoint-colour-rings-2026-10-06` behebt auch 6, 56 und 99 im chronologischen Replay:

| Fall | Ergebnis nach Folgeänderung | Soll |
| --- | --- | --- |
| 6 | T20 | T20 |
| 56 | T20 | T20 |
| 99 | T1 | T1 |
| 111 | 3 | 3 |

**6 und 99:** Die bisherige Spitzensuche verwarf den sichtbaren Endpunkt wegen des maximalen Abstands von 25 mm zur unsicheren Ein-Kamera-Schätzung. Nur bei Ein-Kamera-Treffern wird dieser Abstand jetzt bis 45 mm zugelassen. Bei genau einem Endpunkt mit mindestens 0,85 Konfidenz wird dieser statt des erzwungenen Änderungsschwerpunkts verwendet. Die vorhandenen Prüfungen auf zusammenhängende Pixel, Mindestlänge und Suchrand sowie die zeitliche Entscheidung bleiben aktiv. Der Endpunkt wird ausdrücklich nicht als unabhängig durch mehrere Kameras bestätigt bezeichnet. Im Replay liefern zwei aufeinanderfolgende Bilder T20 beziehungsweise T1.

**56:** Zwei Spitzenendpunkte bestätigen den Triple-Kontakt, ihre Streuung liegt aber über dem alten 2-mm-Limit. Ringprüfung akzeptiert bis 4 mm Streuung und bis 6 mm Abstand zur ursprünglichen Schätzung. Sie verlangt weiterhin dieselbe Sector-Zuordnung und zwei Ansichten mit lokalen neuen Kontaktpixeln und gemessenen Kanten. Der Abstand des Kandidaten zur tatsächlichen Kante muss zusätzlich seine Endpunktunsicherheit plus 0,25 mm überschreiten. Eine Ansicht ohne verwertbare Achse kann durch mindestens sechs neue lokale Kontaktpixel stützen; eine passende Spitze/Achse benötigt mindestens vier zusammenhängende Pixel. Die zwei unabhängigen Spitzen bleiben Voraussetzung. Konsistente Drei-Kamera-Intersektionen werden nicht von nur zwei Spitzen überschrieben.

Farbkanten werden nur als Ergänzung benutzt, wenn die Graukante nicht ausreichend messbar ist. Der Farbkanal `max(R,G)-B` unterscheidet rote/grüne Ringflächen von neutralen Nachbarflächen. Die bestehende Prüfung auf eindeutige Übergänge, Abdeckung und geringe Streuung gilt auch dabei. Farbleerbilder werden je unveränderter Leerreferenz einmal decodiert und schwach gecacht. Der normale schnelle Bewegungsweg erhält keine neue Bildvollscan-Schleife. Replay und Regression laden die originalen gespeicherten Farbleerbilder; die Kalibrierung bleibt unverändert.

Die drei Fälle wurden mit allen acht Originalframes als feste Regressionen aufgenommen. 239 Autoscoring-Tests bestanden; anschließend 23 gezielte Farb-/Kontakt- und Originalvideo-Tests bestanden. Der Farbtest prüft ausdrücklich eine Ringkante ohne Graukontrast. Die 25 alten Pakete bleiben unverändert. In der ersten zusätzlichen Altserie verbessert sich `autoscore_korrektur11` von MISS auf das korrigierte D10. Die alten offenen Fälle 173 und 92 bleiben falsch (20 statt 5 beziehungsweise 19 statt 3); Fall 183 bleibt korrekt 20. Vier richtige Ergebnisse in ausgewählten Fehlerfällen beweisen keine allgemeine Genauigkeit von 99,5 Prozent. Live-Würfe und USB-Latenz wurden nicht geprüft.

Nachprüfbare Ergebnisse liegen unter `build/autoscore_analysis/endpoint_ring_final_trial.json`, `endpoint_ring_old25.json`, `endpoint_ring_preupdate.json` und `endpoint_ring_*` für die zusätzlichen Altserien. Testprotokolle: `endpoint_ring_all_tests.log` und `endpoint_ring_final_guards.log`.
