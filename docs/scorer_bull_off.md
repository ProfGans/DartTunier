# Ausbullen vor dem Scorer-Spiel

Im zweiten Einrichtungsschritt stehen Ohne Ausbullen (Vorgabe), WDF und PDC / DRA zur Wahl. Ohne Ausbullen wird der Anwerfer direkt ausgewählt. Die anderen Optionen öffnen vor dem lokalen oder ferngesteuerten Spielstart einen eigenen Ablauf. Abbrechen startet kein Spiel. Das fertige Ergebnis wird über das bestehende `startingPlayer` gespeichert; es gibt keine Änderung am Speicherformat.

Regelgrundlage, abgerufen am 8. Oktober 2026:

- [WDF Playing and Tournament Rules, Revision 20](https://dartswdf.com/storage/uploads/fb05b306-c92c-4f08-b512-affb092a1b3d/2018-02-28_WDF_Playing_and_Tournament_Rules_rev20.pdf), 12.01–12.03: ausgeloste erste Wurfreihenfolge; Sieger beginnt; Bull und 25 jeweils gleichwertig innerhalb ihres Feldes; außerhalb entscheidet die Nähe zum Zentrum; Gleichstand führt zur Wiederholung in umgekehrter Reihenfolge.
- [DRA Rulebook](https://www.thedra.co.uk/dra-rulebook), Ausgabe 2026, gültig ab 31. März 2026, 6.13.1–6.13.7: Bull und 25 zählen für die Entscheidung, außerhalb gleichwertig; Wiederholung bei Gleichstand in umgekehrter Reihenfolge; Gewinner entscheidet über den Anwurf.

Ein Dart muss stecken bleiben. Abpraller werden wiederholt. Bull und 25 vor dem nächsten Wurf entfernen. Je Doppelteam wirft ein Mitglied. Bei mehr als zwei Seiten nutzt die App eine ausdrücklich gekennzeichnete Erweiterung: Nur gleichauf liegende Führende wiederholen. Die übrige Reihenfolge bleibt erhalten, der ermittelte Starter setzt den Beginn der Rotation.

Menschen tragen ihre Treffer manuell ein; bei WDF außerhalb den Abstand am Eintrittspunkt in Millimetern. Nicht unterscheidbare Abstände werden gleich eingetragen. Die Kameraerkennung ist in diesem Vorbereitungsschritt nicht angeschlossen. Bots nutzen die bestehende BotEngine mit dem aufgelösten Profil einschließlich Theo-Average und Ziel Bull; ein siegreicher Bot wählt den eigenen Anwurf. Bot-Abstände werden aus der vorhandenen Board-Geometrie umgerechnet.

Tests: `flutter test test/bull_off_test.dart`. Optionale gerenderte Vorschauen: `--dart-define=LAYOUT_PREVIEW_FONT=C:/Windows/Fonts/arial.ttf`, Ausgabe unter `build/layout_previews/bull_off_*.png`.
