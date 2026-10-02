# Community-Profil

Der Menüpunkt **Community bearbeiten** steht ganz unten unter **Einladen**.
Inhaber und Mitglieder mit dem Rollenrecht **Community bearbeiten** öffnen dort
die Einstellungen. Dort lassen sich Name (maximal 80 Zeichen), Bio (maximal 1000
Zeichen) und Profilbild ändern; das Bild kann auch entfernt werden.

JPG, PNG und WebP werden über die System-Dateiauswahl geöffnet. Vor dem Dekodieren
werden Dateigröße (5 MB) und Bildabmessungen (20 Megapixel) geprüft. Die App richtet
das Bild anhand seiner Orientierung aus und erzeugt ein quadratisches JPEG mit
256 × 256 Pixeln. Das erzeugte Bild enthält keine ursprünglichen EXIF-Metadaten.
Gespeichert wird ausschließlich diese verkleinerte Fassung.

Die Bio verwendet das bestehende Feld `description`. Das optionale Bildfeld
`avatar_base64` ist auf 128 KiB Text begrenzt und wird mit dem Community-Datensatz
und dessen Offline-Cache geladen. Alte Cacheeinträge ohne Bild bleiben lesbar.
Speichern erfordert eine Online-Verbindung; Eingaben bleiben bei Fehlern erhalten.

Migration `202610020003_community_profile.sql` wurde am 02.10.2026 auf Projekt
`hnsyvqtqxdsbbyrayobv` ausgeführt und geprüft. Die vorhandenen RLS-Regeln bleiben
aktiv: Mitglieder und Inhaber dürfen die Community lesen. Migration
`202610020006_community_edit_permission.sql` wurde ebenfalls am 02.10.2026
eingespielt. Die neue RPC prüft `edit_community` und ändert ausschließlich
Name, Bio und Profilbild. Bestehende Rollen erhalten das Recht nicht automatisch;
der Inhaber kann es unter **Rollen & Rechte** zuweisen. Inhaberschaft und
Einladungscode sind über diese RPC nicht änderbar. Es werden weder öffentliche Bild-URLs noch ein zusätzlicher
Storage-Bucket benötigt.

Tests: Bildverarbeitung, ungültige Dateien, Formularzustand bei 360×800,
800×600 und 1440×900 mit doppelter Schriftgröße; zusätzliche Seitenmatrix.
Eine physische Android-Dateiauswahl wurde nicht geprüft.
