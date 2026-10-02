import 'package:flutter/material.dart';

/// Scrollable, German date entry without fixed-width calendar headers.
class StatisticsDateDialog extends StatefulWidget {
  const StatisticsDateDialog({super.key, this.initialRange});
  final DateTimeRange? initialRange;

  @override
  State<StatisticsDateDialog> createState() => _StatisticsDateDialogState();
}

class _StatisticsDateDialogState extends State<StatisticsDateDialog> {
  final form = GlobalKey<FormState>();
  late final start = TextEditingController(
    text: format(widget.initialRange?.start),
  );
  late final end = TextEditingController(
    text: format(widget.initialRange?.end),
  );

  String format(DateTime? date) => date == null
      ? ''
      : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  DateTime? parse(String value) {
    final match = RegExp(
      r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$',
    ).firstMatch(value.trim());
    if (match == null) return null;
    final day = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final year = int.parse(match[3]!);
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  String? validate(String? value, {bool isEnd = false}) {
    final date = parse(value ?? '');
    if (date == null) return 'Gültiges Datum als TT.MM.JJJJ eingeben.';
    final now = DateTime.now();
    if (date.isBefore(DateTime(1970)) ||
        date.isAfter(DateTime(now.year, now.month, now.day))) {
      return 'Datum zwischen 01.01.1970 und heute wählen.';
    }
    final first = parse(start.text);
    if (isEnd && first != null && date.isBefore(first)) {
      return 'Ende darf nicht vor dem Beginn liegen.';
    }
    return null;
  }

  void submit() {
    if (!form.currentState!.validate()) return;
    Navigator.pop(
      context,
      DateTimeRange(start: parse(start.text)!, end: parse(end.text)!),
    );
  }

  @override
  void dispose() {
    start.dispose();
    end.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Zeitraum wählen'),
    scrollable: true,
    content: SizedBox(
      width: 400,
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: start,
              autofocus: true,
              keyboardType: TextInputType.datetime,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Von',
                hintText: 'TT.MM.JJJJ',
                errorMaxLines: 4,
              ),
              validator: (value) => validate(value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: end,
              keyboardType: TextInputType.datetime,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => submit(),
              decoration: const InputDecoration(
                labelText: 'Bis',
                hintText: 'TT.MM.JJJJ',
                errorMaxLines: 4,
              ),
              validator: (value) => validate(value, isEnd: true),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(onPressed: submit, child: const Text('Anwenden')),
    ],
  );
}
