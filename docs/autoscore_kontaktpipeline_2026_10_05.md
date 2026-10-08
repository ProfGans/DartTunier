# Kontaktpipeline, Bildlabels und unabhängige Prüfserien

## Implementierter Umfang

1. **Direkter Kontaktvergleich:** bis zu acht räumlich begrenzte Kandidaten
   aus der bisherigen Position, sichtbaren Endpunkten und Kameraachsenpaaren
   werden in alle drei Original-Detailbilder projiziert. Neue lokale Pixel,
   Endpunktnähe und Achsenabstand werden je Kamera protokolliert. Das läuft
   parallel (`mode: shadow`) und überschreibt keinen Treffer.
2. **Verdeckungsbewertung:** vorhandene belegte Pixel, fehlende neue Pixel und
   Nähe zu bereits gezählten Darts markieren vermutete Verdeckung. Solche
   Perspektiven erhalten weniger Gewicht im parallelen Vergleich. Fehlende
   Detailbilder bedeuten fehlende Evidenz, keine nachgewiesene Verdeckung.
3. **Ring- und Außenrandprüfung:** Triple-/Double-Grenzen bei 99, 107, 162 und
   170 mm werden lokal im Detail-Leerbild geprüft. Mindestens zwei sichtbare
   Endpunkte, neue Kontaktpixel und gemessene Ringübergänge müssen eine kleine
   Korrektur bestätigen. Der Übergang bei 170 mm entscheidet auch zwischen
   Double und schwarzem Außenbereich mit 0 Punkten. Ein gleichzeitig wechselnder
   Sektor wird abgelehnt. Diese Prüfung ist produktiv aktiv, ergänzt die
   vorhandene Segmentprüfung und erzeugt keine neuen Treffer ohne Dart-Evidenz.
4. **Kleines Kontaktmodell vorbereiten:** unabhängige Originalbildmarkierung,
   Datensatzaufbereitung und ein offline CNN-Prototyp mit Kontakt-Heatmap und
   Verdeckungs-Ausgabe sind vorhanden. Modelltraining und Aktivierung sind
   nicht erfolgt, weil das vorhandene Material noch keine geprüften Bildlabels
   enthält. PyTorch ist für tatsächliches Training erforderlich und derzeit
   nicht installiert; die Datenvalidierung braucht es nicht.
5. **Richtige und falsche Würfe sammeln:** optionale Prüfserien speichern auch
   richtige Würfe samt Diagnosebildern, Szenario, Datensatzpartition und
   Bestätigungsquelle. Aufnahme, Score und automatische Erkennung laufen weiter.

Neue Diagnosefelder: `contactCandidateComparison`, `localRingContact`,
`cameraTrainingLabels`, `validationSession`, `validationCategory`,
`datasetSplit`, `verificationSource`. Das Berichtsschema bleibt additiv
Version 8. Neue Algorithmusrevision: `contact-evidence-v2-2026-10-05`.
Trainingslabel-, Datensatz- und Prüfserienformate besitzen jeweils Schema 1.

## Bedienung

Im Autoscorer den Bereich **„Prüfserie: richtige und falsche Würfe sammeln“**
öffnen, Wurfsituation und Training/Validierung/Test wählen und starten.
Nach dem Werfen jedes Ergebnis prüfen: richtig bestätigen, falsch korrigieren
oder einen fehlenden Dart nachtragen. Unkorrigiertes Herausziehen behält die
bisherige Genauigkeitsstatistik bei, zählt in der Prüfserie aber ausdrücklich
nicht als unabhängige Referenz. Nach dem Beenden ausstehende Exporte abwarten.
Der angezeigte Ordner enthält ZIPs und `pruefserie.json`. Exportfehler und
ausgelassene Exporte bleiben sichtbar; es gibt keinen stillen vollständigen
Genauigkeitsnachweis bei fehlenden Aufnahmen.

Im geprüften Trefferverlauf **„Originalbilder markieren“** wählen. Für jede
Kamera angeben, ob die Spitze sichtbar, verdeckt oder unklar ist. Bei sichtbarer
Spitze diese sowie zwei Punkte auf dem zugehörigen Schaft direkt im Bild setzen.
Zoomen ist möglich; die Pfeiltasten verschieben nach einem Klick die gewählte
Markierung. Bestehende Markierungen werden beim erneuten Öffnen geladen.
Die Markierungen werden in der Diagnose gespeichert und bei aktiver Prüfserie
auch dort aktualisiert. Sie verändern weder Score noch automatische Erkennung.

## Modellwerkzeuge

Datensatzaufbereitung:

```powershell
flutter test tool/autoscore_prepare_model_dataset_test.dart --dart-define=TRAINING_ZIP_ROOT=PFAD_ZUM_GEMEINSAMEN_PRUEFSERIENORDNER
```

Standardausgabe: `build/autoscore_analysis/contact_model_dataset.json`.
Nur direkt geprüfte Originalbildlabels werden verwendet. Der 32×32-Ausschnitt
ist um die automatische Vorhersage zentriert, nie um die manuelle Wahrheit;
zwei Kanäle enthalten Helligkeit und Bildänderung. Fehlende Referenzen,
unvollständige Labels und Ziele außerhalb des Ausschnitts werden ausgelassen.
Bei mehrfacher Bildprüfung bleibt die neueste verfügbare Version je Capture
und Kamera. Das Werkzeug verändert keine Original-ZIPs.

Datensatz prüfen und – erst nach ausreichender Sammlung – Modell trainieren:

```powershell
python tool/train_contact_model.py build/autoscore_analysis/contact_model_dataset.json build/autoscore_analysis/contact_model --validate-only
python tool/train_contact_model.py build/autoscore_analysis/contact_model_dataset.json build/autoscore_analysis/contact_model
```

Training verlangt explizite getrennte Serien und mindestens 20 geprüfte
Kamerabeispiele pro Partition, mit sichtbaren und verdeckten Spitzen. Das ist
eine technische Mindestgröße für den Prototyp, kein Genauigkeitsnachweis.
Capture-, Serien- und identische Leerreferenz-Gruppen dürfen keine Partitionen
überkreuzen. Hash-Gruppen verhindern exakte Referenzduplikate, beweisen aber
keine physische Unabhängigkeit: neue Setups, Tage und Beleuchtung müssen
zusätzlich für einen aussagekräftigen Holdout gesammelt werden.

Der Trainer nutzt Training zum Lernen und Validierung zur Modellauswahl;
Testdaten werden erst danach ausgewertet. Er exportiert Gewichte, TorchScript
und einen Bericht über Pixelabweichung und Verdeckung. `modelActivated=false`
bleibt bestehen. Es gibt keine automatische Anbindung dieser experimentellen
Gewichte an den laufenden Scorer und keine behauptete Score-Genauigkeit daraus.

## Bisherige Prüfung

- Die 25 alten Pakete sowie die vier zusätzlichen Stapel mit 13, 6, 4 und 3
  Paketen liefern unveränderte Ergebnisse gegenüber dem vorherigen Stand.
  Diese Pakete können sich überschneiden.
- Die bereits behobenen Sequenzen 5, 97, 126, 42, 20, 183, 27 und 89 bleiben
  korrekt. Bei 173 und 92 schlägt der parallele Vergleich 5 und 3 vor; die
  aktive Entscheidung bleibt weiterhin 20 und 19. Diese Vorschläge sind noch
  kein Beleg für eine allgemein sichere automatische Übernahme.
- Synthetische Tests prüfen alle vier Ringgrenzen, fehlende Kontraste,
  unzureichende Endpunkte, Verdeckungsgewichtung, fehlende Detailbilder,
  Trainingslabel-Gates und Vorhersagezentrierung.
- Prüfserientests sichern Speicherung richtiger/falscher/unbestätigter Würfe
  und die Trennung automatischer von manueller Bestätigung ab.
- Neue Widget-Tests prüfen 360×800, 800×600 und 1440×900 mit normaler und
  doppelter Schrift sowie die Übereinstimmung von Klick- und Markerposition.
  Gerenderte mobile und Desktop-Vorschauen wurden gesichtet. Live-USB-Würfe
  und echte mobile Geräte wurden nicht geprüft.
- Der zusätzliche Vergleich benötigte im Replay der drei offenen Sequenzen
  maximal etwa 1,6 ms je ausgeführtem Vergleichsschritt. Das ist keine
  garantierte Gesamt- oder Live-Latenz.

Logs und Ergebnisse: `build/autoscore_analysis/contact_pipeline_*`.
272 relevante Tests bestanden, zusätzlich die gemeinsamen Layoutprüfungen
und fünf Python-Tests für die Trainingsdatenvalidierung. Windows-Release-Build
erfolgreich. Die statische Analyse enthält nur den bestehenden Lint-Hinweis
in `test/manual_update_card_test.dart:35`.
Die Zielgenauigkeit von 99,5 Prozent ist weiterhin nicht nachgewiesen.
