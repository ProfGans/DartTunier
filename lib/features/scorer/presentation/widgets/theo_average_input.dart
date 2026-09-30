import 'package:flutter/material.dart';
import '../../application/theo_average_service.dart';

class TheoAverageInput extends StatelessWidget {
  const TheoAverageInput({
    super.key,
    required this.controller,
    this.enabled = true,
  });
  final TextEditingController controller;
  final bool enabled;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: const InputDecoration(
      labelText: 'Theo-Average',
      helperText:
          'Theoretischer 3-Dart-Average · z. B. 60,5\n35–120: vorberechnete Werte wie in der anderen App.',
      helperMaxLines: 3,
    ),
    validator: (v) => TheoAverageService.parse(v ?? '') == null
        ? 'Average größer als 0 bis höchstens 180 eingeben.'
        : null,
  );
}
