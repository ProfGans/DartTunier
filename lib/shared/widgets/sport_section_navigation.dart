import 'package:flutter/material.dart';

class SportSection<T> {
  const SportSection(this.value, this.label, this.icon);
  final T value;
  final String label;
  final IconData icon;
}

class SportSectionNavigation<T> extends StatelessWidget {
  const SportSectionNavigation({
    super.key,
    required this.label,
    required this.sections,
    required this.selected,
    required this.onChanged,
  });
  final String label;
  final List<SportSection<T>> sections;
  final T selected;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      if (constraints.maxWidth < 840 * scale) {
        return DropdownButtonFormField<T>(
          key: ValueKey(selected),
          initialValue: selected,
          isExpanded: true,
          isDense: false,
          itemHeight: null,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(
              sections.firstWhere((section) => section.value == selected).icon,
            ),
          ),
          items: [
            for (final section in sections)
              DropdownMenuItem(
                value: section.value,
                child: Text(section.label),
              ),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        );
      }
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final section in sections)
              ChoiceChip(
                showCheckmark: false,
                avatar: Icon(section.icon, size: 20),
                label: Text(section.label),
                selected: section.value == selected,
                onSelected: (_) => onChanged(section.value),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
          ],
        ),
      );
    },
  );
}
