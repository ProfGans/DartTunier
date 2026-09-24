import 'package:supabase_flutter/supabase_flutter.dart';

String deviceErrorMessage(Object? error) {
  if (error is PostgrestException) {
    if (const {'PGRST205', 'PGRST202', '42P01', '42883'}.contains(error.code)) {
      return 'Die Gerätefunktion ist auf dem Server noch nicht eingerichtet. '
          'Bitte die Supabase-Gerätemigrationen installieren.';
    }
    if (const {'42501', 'PGRST301', 'PGRST303'}.contains(error.code)) {
      return 'Kein Zugriff auf die Geräte. Bitte erneut anmelden und die Gruppenberechtigung prüfen.';
    }
  }
  return 'Geräte konnten nicht geladen werden. Bitte die Verbindung prüfen und erneut versuchen.';
}
