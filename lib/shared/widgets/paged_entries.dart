import 'package:flutter/material.dart';

/// Bounded widget construction for long histories inside an existing scroller.
class PagedEntries<T> extends StatefulWidget {
  const PagedEntries({super.key, required this.entries, required this.builder});
  final List<T> entries;
  final Widget Function(T) builder;
  @override
  State<PagedEntries<T>> createState() => _PagedEntriesState<T>();
}

class _PagedEntriesState<T> extends State<PagedEntries<T>> {
  static const pageSize = 40;
  int _page = 0;
  @override
  Widget build(BuildContext context) {
    final last = widget.entries.isEmpty
        ? 0
        : (widget.entries.length - 1) ~/ pageSize;
    final page = _page.clamp(0, last);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (last > 0)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Seite ${page + 1} von ${last + 1} · ${widget.entries.length} Einträge',
              ),
              OutlinedButton(
                onPressed: page == 0
                    ? null
                    : () => setState(() => _page = page - 1),
                child: const Text('Vorherige Seite'),
              ),
              OutlinedButton(
                onPressed: page == last
                    ? null
                    : () => setState(() => _page = page + 1),
                child: const Text('Nächste Seite'),
              ),
            ],
          ),
        for (final entry in widget.entries.skip(page * pageSize).take(pageSize))
          widget.builder(entry),
      ],
    );
  }
}
