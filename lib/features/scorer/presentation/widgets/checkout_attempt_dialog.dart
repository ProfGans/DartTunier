import 'package:flutter/material.dart';

/// null = cancelled; (null,) = explicitly unknown; (n,) = recorded attempts.
Future<(int?,)?> askCheckoutAttempts(
  BuildContext context, {
  required int maximum,
  required bool finish,
}) {
  return showDialog<(int?,)>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Darts auf Checkout'),
      content: Text(
        finish
            ? 'Wie viele Darts dieser Aufnahme waren Versuche auf das beendende Doppel/Bull – einschließlich des Treffers?'
            : 'Wie viele Darts dieser Aufnahme hast du auf das beendende Doppel/Bull geworfen? Eröffnungsdoppel nicht mitzählen.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, (null,)),
          child: const Text('Nicht erfasst'),
        ),
        for (var n = finish ? 1 : 0; n <= maximum; n++)
          FilledButton(
            onPressed: () => Navigator.pop(context, (n,)),
            child: Text('$n Versuch${n == 1 ? '' : 'e'}'),
          ),
      ],
    ),
  );
}
