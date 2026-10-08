# Diagnosen aus Neuer Ordner (9)

Quelle: autoscore_korrektur_2.zip, autoscore_korrektur_56.zip und autoscore_korrektur_68.zip. Fall 68 wurde vom Nutzer ausdrücklich als Bouncer bezeichnet. Das im Export gespeicherte MISS wird deshalb als Nullwurf ohne steckenden Dart bewertet. Der verschobene Boardpunkt bei 68 ist keine tatsächliche Einschlagposition für die Erkennung.

| Fall | Gespeichert live | Aktueller Video-Replay | Soll |
| --- | --- | --- | --- |
| 2 | 5 | 5 | T5 |
| 56 | MISS | MISS | T20 |
| 68 | 16 | 13 | Bouncer, 0 Punkte |

Alle Pakete enthalten bereits `visible-endpoint-colour-rings-2026-10-06`. Die Fälle 56 und 2 sind neue Aufnahmen und dürfen nicht mit gleich nummerierten früheren ZIPs verwechselt werden.

## Fall 68

Die gespeicherten drei Entscheidungsproben haben jeweils null brauchbare Achsen, views=0 und residual=230 mm. Die erzwungenen Punkte springen von (-68,65) über (107,-48) nach (58,174). Die begrenzte zeitliche Auswahl übernimmt davon ein Punktefeld, obwohl ein steckender Kontakt nicht belegt ist. Der Replay liefert ebenfalls einen falschen Treffer, allerdings 13 statt der live gespeicherten 16. Er rekonstruiert nicht den gesamten vorherigen Sitzungsverlauf; die Abweichung darf nicht als zuverlässige Rekonstruktion des Live-Scores ausgegeben werden.

Die Bouncer-Stufe der gespeicherten letzten zwölf Verarbeitungsschritte zeigt jeweils einen leeren Zustandsbericht. Daraus lässt sich weder ein erfolgreicher Bouncer-Kandidat noch die genaue Ablehnungsbedingung nachweisen. Die richtige Folgerung ist: Null-Achsen-Zwangsschätzungen dürfen bei einem verschwundenen Wurf keinen positiven Score erfinden. Die Bewegung und der anschließend fehlende neue Kontakt müssen gemeinsam geprüft werden. Null Achsen allein beweisen keinen Bouncer, weil auch verdeckte steckende Darts keine Achsen liefern können.

## Fall 2

Nur Kamera 1 liefert einen verwertbaren Spitzenendpunkt. Die drei gespeicherten Proben lauten ungefähr (-18,78,-103,92), (-19,27,-109,06) und (-19,05,-110,55). Die erste liegt im Triple, danach wandert der Endpunkt über die äußere Triple-Grenze. Die zeitliche Auswahl akzeptiert zwei nahe beieinander liegende Single-Schätzungen. Der manuell gesetzte T5-Punkt liegt ungefähr 7,2 mm vom übernommenen Punkt entfernt. Ursache ist hier die instabile Kontaktlokalisierung am Ring, nicht ein fehlender Wurf oder das frühere 25-mm-Suchlimit. Frühe Spitzen-, lokale Ring- und Sichtbarkeitsdaten müssen zusammen geprüft werden; pauschal den ersten Punkt zu bevorzugen wäre keine sichere Korrektur.

## Fall 56

Zwei Achsen liefern eine stabile, aber falsche Intersektion bei ungefähr (-92,-147), außerhalb des Double-Rings. Keine Spitzenbeobachtung bestätigt diesen Punkt. Die bestehende Wiederherstellung prüft den Fall, erzeugt aber keine ausreichend bestätigte alternative Hypothese. Die Kamerabilder zeigen eine enge Gruppe im oberen Boardbereich. Dieses Beispiel verlangt eine bessere Zuordnung neuer Schaftanteile zum selben Dart. Eine Ringkorrektur kann einen so weit entfernten falschen Kandidaten nicht retten. Ein manuell markierter Originalbildkontakt fehlt; die Korrektur liefert nur den Sollscore T20.

## Nachprüfbarkeit

Chronologischer Replay mit tool/autoscore_new_video_replay_test.dart, VIDEO_REPLAY_CASES=2,56,68 und VIDEO_REPLAY_ROOT=build/autoscore_analysis/new_2_56_68_oct9. Ergebnis: build/autoscore_analysis/new_2_56_68_results.json; Protokoll: build/autoscore_analysis/new_2_56_68_replay.log. Die Kameraübersichten wurden zusätzlich visuell geprüft. Ein erfolgreich ausgeführter Replay-Test bestätigt keine korrekte Wertung. In dieser Untersuchung wurde die Erkennungslogik nicht geändert.

## Umsetzung: transient-bounce-shaft-history-2026-10-06

Alle drei Fälle werden nach dieser Folgeänderung korrekt gewertet: 2 als T5, 56 als T20, 68 als Bouncer (0). Auswertung: build/autoscore_analysis/ordner9_bounce_trial.json. Die gespeicherten Sollwerte und Fallnummern werden nicht zur Erzeugung der Schätzungen verwendet.

- **2:** Nur im bereits unsicheren Ein-Kamera-Endpunktzweig wird der Differenzschwellwert von 24 auf 18 gesenkt. Unverändert gelten mindestens drei verbundene Nachbarpixel, Mindestlänge, Achskonfidenz mindestens 0,85, maximal 45 mm Entfernung und zeitliche Entscheidung. Dadurch bleibt die echte schwache Spitze in zwei Bildern bei ungefähr (-19,29,-102,64) sichtbar, statt zum oberhalb liegenden Schaftanfang zu wandern. Der Mehrkamera-Zweig behält Schwelle 24.
- **56:** Ein eigener begrenzter Speicher hält bis zu drei starke Achsen pro Kamera für maximal 100 ms am selben belegten Referenzbild. Sie sind ausschließlich alternative Vorschläge für die bestehende Wiederherstellung. Sie werden nicht direkt übernommen. Die vorhandene Prüfung verlangt weiterhin neue Schaftpixel in beiden beteiligten Kameras, neue lokale Pixel in der dritten Kamera und Übereinstimmung auf zwei verschiedenen zeitgestempelten Aufnahmen. Hier wird T20 bei ungefähr (-1,60,-102,36) mit neun neuen Pixeln in der dritten Kamera bestätigt. Referenzwechsel, abgelaufene oder rückwärts laufende Zeitstempel verwerfen die alten Linien; wiederholte identische Zeitstempel erzeugen keine neue Historie.
- **68:** Ergänzend zum bestehenden Bouncer-Zweig wird eine örtlich begrenzte vorübergehende Änderung in mindestens zwei Kameras verfolgt. Mindestens eine Ansicht muss einen Peak zwischen 1,5 und 6 Prozent geänderter Pixel zeigen. Innerhalb von 900 ms muss dieser auf höchstens 45 Prozent zurückgehen; zwei ruhige Beobachtungen ohne bleibende primäre Schaftachse sind nötig. Große Bewegungen, bleibende Achsen und abgelaufene Beobachtungen werden abgelehnt. Das toleriert kleine Reständerungen durch bereits steckende, vibrierende Darts und stoppt in diesem Fall die anschließende Null-Achsen-Punkteschätzung. Der angenommene Bouncer wird ausdrücklich als solcher mit null Punkten erfasst, nicht als räumlicher Kontakt. Bewegungspeak, aktuelle Änderung, Zeit, Achsenanzahl und Annahme werden im Diagnoseverlauf protokolliert.

249 Autoscoring-Tests bestanden. Die drei echten Bildfolgen sind als getrennte ordner9-Regressionsfixtures hinterlegt. Zusätzliche Unit-Tests prüfen die Bouncer-Vetos und die begrenzte Achshistorie. Der chronologische Replay der vorherigen Fälle 6, 56, 99 und 111 bleibt korrekt. Die 25 alten Pakete sowie die vier zusätzlichen Altserien (13, 6, 4 und 3 Pakete; teilweise überlappend) liefern unveränderte Ergebnisse gegenüber der vorherigen Revision. Analyse meldet ausschließlich den bestehenden Hinweis in test/manual_update_card_test.dart:35. Protokolle: ordner9_all_tests_final.log, ordner9_final_guards.log, ordner9_analyze_final.log und ordner9_* für die Altserien.

Das ist eine Absicherung der bekannten Aufnahmen, keine Garantie für beliebige Bouncer oder vollständig verdeckte Darts. Die Bouncer-Regel verwendet Bildbewegung und fehlende bleibende Schäfte als Indizien; null Achsen allein zählen weiterhin nicht als Bouncer. Keine neuen Live-Würfe mit USB-Kameras wurden durchgeführt und das Ziel 99,5 Prozent ist damit nicht nachgewiesen.
