# Persönliches Profil

Angemeldete Online-Konten speichern Name, Nationalität, Walk-on-Song, Spotify-Link, Lieblingsspieler, Lieblingsdoppel und das verkleinerte Profilbild in `public.personal_profiles`. Row Level Security erlaubt ausschließlich dem jeweiligen Konto Lese- und Schreibzugriff.

Der lokale Cache bleibt offline nutzbar. Änderungen werden zunächst kontogetrennt lokal vorgemerkt und anschließend hochgeladen. Beim Öffnen des Profils und über „Profil synchronisieren“ wird erneut abgeglichen. Vorhandene lokale Profile werden beim ersten Online-Abgleich automatisch übernommen. Auf weiteren Geräten wird das online gespeicherte Profil geladen. Bei konkurrierenden Offline-Änderungen gilt der zuletzt erfolgreich hochgeladene Stand.

Der persönliche Profilname ist unabhängig vom Anmeldenamen und bereits gespeicherten Turnier-Spielernamen.

Migration: `supabase/migrations/202610020004_personal_profiles.sql`. Am 02.10.2026 im bestehenden App-Supabase-Projekt erfolgreich ausgeführt. Es wurden keine echten Nutzerprofile als Testdaten verändert.

Prüfung: `flutter test test/personal_profile_sync_test.dart test/personal_profile_test.dart test/adaptive_layout_test.dart test/responsive_pages_test.dart` und `node tool/test_personal_profiles.mjs`. Der SQL-Test prüft die Migration und den Schutz gegen kontofremden und anonymen Zugriff. Ein Durchlauf mit zwei echten angemeldeten Geräten steht noch aus.

## Dart-Setup

Das persönliche Profil enthält optional Darts/Barrel, Gewicht, Shafts, Flights, Spitzen und weitere Angaben. Das Setup wird im bestehenden privaten Online-Profil mitgespeichert. Es verwendet ein eigenes versioniertes JSON-Objekt `dartSetup` (Version 1). Bestehende Profile ohne dieses Objekt werden beim Lesen auf ein leeres Setup migriert; die Profilversion und bestehenden Datenbank-Zugriffsregeln bleiben kompatibel. Dafür ist keine zusätzliche Servermigration erforderlich.

## Lieblingsdoppel und Checkoutwege

Der Scorer und der Checkoutrechner berücksichtigen das gespeicherte Lieblingsdoppel (D1–D20 oder Bull/D25). Ein erreichbarer Weg auf dieses Finish wird vor den Standardalternativen angezeigt, höchstens fünf eindeutige Wege insgesamt. Im Match gilt die Präferenz ausschließlich für den dem eigenen Account zugeordneten Spieler. Ohne gültige Präferenz, bei nicht erreichbarem Finish oder fehlenden Profildaten bleiben die Standardwege erhalten. Die Out-Regel und verbleibenden Darts werden weiterhin eingehalten; Bot-Strategien bleiben unabhängig davon.
