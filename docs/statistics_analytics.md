# Ausführliche Spieler- und Community-Statistiken

Das Statistik-Cockpit ist erreichbar über:

- Mein Profil → direkt eingebettetes Cockpit
- Spieler → Spieler auswählen
- Community → Statistiken → direkt eingebettetes Cockpit
- Community-Mitglied → ausführliche Statistik und Kennzahlen-Details

## Rubriken

40 Kennzahlen sind auf sechs Bereiche verteilt: Ergebnisse, Legs & Sets, Scoring, Checkout, Legqualität sowie Aktivität & Datenbasis. Jede Kennzahl hat eine eigene Detailseite mit Erklärung und Datenbasis, auswählbarem Verlauf, kumulierter Gesamtentwicklung, einem Formvergleich der jüngsten fünf gegen die fünf vorherigen messbaren Begegnungen, Minimum/Maximum, Median, Standardabweichung, Verteilung, Gegnerauswertung und allen Einzelwerten. Die Grafik zeigt maximal 30 jüngste Messpunkte; die Einzelwertliste enthält alle Beobachtungen im Filter. Messpunkte lassen sich per Touch/Maus und über eine tastaturbedienbare Auswahl ansteuern.

Das Spieler-Cockpit bietet eine Ergebnisform der letzten zehn abgeschlossenen Spiele, die aktuelle Siegesserie, Zeitraumfilter und Einzel-/Doppelfilter. Detailseiten können zusätzlich nach bekannten Startpunktzahlen filtern. Die Community bietet einen Kennzahlenvergleich aller Spieler mit Balken, Stichprobengröße und Form. Scoring-, Checkout-, Legqualitäts- und Datenbasiswerte können als gemeinsamer Verlauf aller Spielerbeiträge betrachtet werden. Beiträge beider Spieler einer Begegnung sind dort ausdrücklich als Spielerbeiträge gekennzeichnet.

## Berechnung und Grenzen

- Average = 3 × Punkte / Darts; First-9-Average analog aus den ersten drei Aufnahmen je Leg. Quoten werden aus Summen der Zähler und Nenner berechnet, nicht aus dem Mittelwert von Einzelquoten.
- Unvollständige Scorer-Sitzungen tragen Aufnahmen bei, aber kein abgeschlossenes Spielergebnis. Fehlende Messwerte werden als fehlend angezeigt; vorhandene Nullwerte bleiben Null.
- Checkoutquote wird ausschließlich aus Double-Out-Daten mit vollständig bekannten Versuchen berechnet. Unbekannte Versuche verhindern die Gesamtquote; messbare Einzelbegegnungen bleiben sichtbar.
- Persönliche Scorer-Spiele und Turnierergebnisse werden getrennt angezeigt, um übertragene Spiele nicht doppelt zu zählen. Normale lokale Profile werden ausschließlich über Profil-/Account-IDs zugeordnet, nicht über Namensgleichheit.
- Community-Daten stammen ausschließlich aus den vorhandenen Turnieren der jeweiligen Community. Private Scorer-Sitzungen werden nicht zusätzlich veröffentlicht. Bot-Teilnehmer erhalten keine Spielerstatistik.
- Ohne Spielzeit erscheinen ältere Ergebnisse nur unter Gesamt; für ihre Reihenfolge wird das Turnierdatum verwendet und kenntlich gemacht. Bei Liga-Doppeln und Turnier-Teams zählt jeder Spieler seinen gemeinsamen Ergebnisbeitrag; individuelle Scorerwerte werden daraus nicht erfunden.
- Gegnerauswertungen gruppieren nach gespeicherten Gegnernamen; gleiche Namen können mehrdeutig sein. Gemischte Startpunktzahlen, unterschiedliche Gegner und kleine Stichproben begrenzen die Aussagekraft von Formvergleichen.
- Das Cockpit berechnet die Werte aus vorhandenen Snapshots neu, einschließlich Ergebniskorrekturen und annullierten Spielen. Es ändert weder Turnierregeln noch gespeicherte JSON-Schemata; eine neue Datenbankmigration ist nicht erforderlich.

## Architektur und Prüfung

Der Kennzahlenkatalog und die reine Auswertungslogik liegen unter `lib/features/statistics/domain/analytics/`; Diagramme und Detailseiten unter `presentation/analytics/`. Community und lokale Profile nutzen dieselbe Auswertung. Der persönliche Profilbereich und Rubrikenauswahl behalten ihren Zustand beim Scrollen. Die Statistik-Abfrage im Mitgliederprofil ist außerhalb der verzögert aufgebauten Listenabschnitte verankert.

Tests: `test/statistics_analytics_test.dart`, `test/statistics_analytics_widget_test.dart` und die erweiterte gemeinsame Matrix `test/responsive_pages_test.dart`. Sie prüfen gewichtete Berechnung, Datenlücken, Form, Korrekturen, Identitäten, Community-Abgrenzung, leere Daten, sämtliche Detailseiten, 360×800, 800×600, 1440×900 sowie 200 Prozent Textgröße. Die Turnier-Simulationsmatrix bleibt zusätzlich Teil der Regression.

Gerenderte Vorschauen: `flutter test test/statistics_analytics_widget_test.dart --dart-define=LAYOUT_PREVIEW_FONT=C:/Windows/Fonts/segoeui.ttf`, Ausgabe unter `build/layout_previews/`. Die Prüfung ersetzt keinen Test mit zwei echten angemeldeten Geräten.


Das ausführliche Statistik-Cockpit ist die Standardansicht: direkt im eigenen Profil und im Community-Statistikbereich, beim Öffnen normaler Spielerprofile sowie in Community-Spielerprofilen. Gespeicherte Scorer-Spiele öffnen ebenfalls das Cockpit. Bearbeiten bleibt über die Spieleraktionen erreichbar; Highlights und Trends bleiben erhalten.

## Heatmap als Cockpit-Bereich

Die Heatmap erscheint direkt vor den Kennzahlen, mit großem Dartboard, Trefferdichte, häufigsten Feldern und RMS-Streuung. Desktop stellt Board und Auswertung nebeneinander dar; Mobile zeigt das Board zuerst. Zeitraumfilter, Schätzungen und Checkoutversuche bestimmen die Auswahl. Die Detailansicht erhält ausschließlich die bereits zugeordneten Treffer. Eigene Profil-Heatmaps werden über gespeicherte Sitzungs-ID und Spielerindex verbunden, nicht über Namen; Gegner und andere lokale Sitzungen bleiben ausgeschlossen. Einzelspiel-Cockpits erhalten nur ihre Sitzung. Positionen liegen derzeit im lokalen Archiv; Community-Snapshots enthalten noch keine freigegebenen Positionen. Die Community zeigt diesen fehlenden Datenbestand ausdrücklich, statt private lokale Heatmaps einzublenden. Alte Spiele ohne Einschlagpositionen werden nicht rekonstruiert. Speicherschemata bleiben unverändert.
