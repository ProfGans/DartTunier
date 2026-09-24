import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dart_tournament_manager/features/devices/presentation/device_error_message.dart';

void main() {
  test('missing schema is distinguished from access and connection errors', () {
    expect(
      deviceErrorMessage(
        const PostgrestException(message: 'missing', code: 'PGRST205'),
      ),
      contains('noch nicht eingerichtet'),
    );
    expect(
      deviceErrorMessage(
        const PostgrestException(message: 'denied', code: '42501'),
      ),
      contains('erneut anmelden'),
    );
    expect(
      deviceErrorMessage(Exception('network')),
      contains('Verbindung prüfen'),
    );
  });
}
