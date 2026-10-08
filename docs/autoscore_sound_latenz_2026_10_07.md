# Verzögerung bis zum Treffer-Sound

Die am 7. Oktober laufende App wurde anhand des Prozesspfads als Debug-Build
identifiziert: `build/windows/x64/runner/Debug/dart_tournament_manager.exe`.
Für eine belastbare Prüfung der CPU-intensiven Bildauswertung die gebaute
Release-Version verwenden. Die laufende App wurde nicht beendet.

Änderungen:
- Die Kameraquelle verarbeitet bei Rückstand die neuesten drei synchronisierten
  Bildpakete statt alle sechs älteren Pakete weiter abzuarbeiten. Die drei
  zeitlich verschiedenen Beobachtungen bleiben in chronologischer Reihenfolge.
  Ausgelassene Pakete werden als `backlogDroppedBatches` in der Diagnose gezählt.
- Treffer, Bouncer und Herausziehen haben getrennte, vorab geladene Audioplayer.
  Bei einem Treffer wird die bereits geladene Quelle zurückgespult und gestartet,
  statt die WAV-Datei erneut zu öffnen. Fehlgeschlagenes Vorladen wird beim
  tatsächlichen Abspielen erneut versucht und über die bestehende Fehlermeldung
  gemeldet. Sprachansagen und Treffer-Sounds behalten getrennte Warteschlangen.
- Der native Aufnahmeweg meldet das Alter der Bilder beim Auslesen. Die Diagnose
  enthält `oldestBufferedAgeMilliseconds`, `newestBufferedAgeMilliseconds` und
  `nativeReadMilliseconds`. Das Bildalter bezeichnet die Zeit seit Ankunft auf
  dem PC; Verzögerung im Sensor oder USB-Treiber ist darin nicht enthalten.

Bestätigungs- und Geometrieschwellen wurden nicht verkürzt. Das Überspringen
alter Pakete kann bei Überlast kurze Ereignisse auslassen; der Drop-Zähler macht
diese Fälle sichtbar. Deshalb müssen Bouncer auch im Live-Test geprüft werden.
Die gespeicherten chronologischen Bouncer-Regressionen bleiben unverändert.

Verifikation: Audio- und Aufnahme-Tests einschließlich Rückstau, Reihenfolge und
Duplikatschutz bestanden; vollständige Autoscoring-Suite: 251 Tests bestanden.
Eine konkrete Zeit von Einschlag bis hörbarem Sound wurde nicht live gemessen.
