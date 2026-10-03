import 'dart:math';
import 'package:flutter/material.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../data/community_highlights_repository.dart';
import '../domain/community_highlight.dart';

class HighlightEditorPage extends StatefulWidget {
  const HighlightEditorPage({
    super.key,
    required this.communityId,
    required this.repository,
    this.highlight,
  });
  final String communityId;
  final CommunityHighlightsRepository repository;
  final CommunityHighlight? highlight;
  @override
  State<HighlightEditorPage> createState() => _EditorState();
}

class _EditorState extends State<HighlightEditorPage> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.highlight?.title);
  late final _value = TextEditingController(text: widget.highlight?.value);
  late final _player = TextEditingController(text: widget.highlight?.player);
  late final _tournament = TextEditingController(
    text: widget.highlight?.tournament,
  );
  late final _note = TextEditingController(text: widget.highlight?.note);
  late HighlightCategory _category =
      widget.highlight?.category ?? HighlightCategory.other;
  late DateTime _date = widget.highlight?.date ?? DateTime.now();
  late final String _key =
      widget.highlight?.key ??
      'manual:${DateTime.now().microsecondsSinceEpoch}:${Random.secure().nextInt(1 << 32)}';
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_title, _value, _player, _tournament, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.save(
        widget.communityId,
        CommunityHighlight(
          key: _key,
          category: _category,
          title: _title.text.trim(),
          value: _value.text.trim(),
          player: _player.text.trim(),
          tournament: _tournament.text.trim(),
          date: _date,
          note: _note.text.trim(),
          edited: true,
        ),
      );
      if (mounted) Navigator.pop(context, saved);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Speichern nicht bestätigt. Verbindung und Berechtigung prüfen. Deine Eingaben bleiben erhalten.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.highlight == null
            ? 'Highlight hinzufügen'
            : 'Highlight bearbeiten',
      ),
    ),
    body: Form(
      key: _form,
      child: AdaptiveContentList(
        maxWidth: 800,
        children: [
          if (widget.highlight?.automatic == true)
            const Text(
              'Die Korrektur gilt für die Highlight-Liste. Scorer- und Turnierergebnisse bleiben unverändert.',
            ),
          DropdownButtonFormField<HighlightCategory>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Kategorie'),
            items: [
              for (final c in HighlightCategory.values)
                DropdownMenuItem(value: c, child: Text(c.label)),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => _category = value!),
          ),
          _field(_title, 'Titel', 120, required: true),
          _field(_value, 'Wert / Leistung', 80, required: true),
          _field(_player, 'Spieler / Team (optional)', 512),
          _field(_tournament, 'Turnier (optional)', 256),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_month),
            label: Text('Datum: ${highlightDate(_date)}'),
            onPressed: _busy
                ? null
                : () async {
                    final value = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2200),
                    );
                    if (value != null && mounted) setState(() => _date = value);
                  },
          ),
          _field(_note, 'Notiz (optional)', 1000, lines: 3),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Wird gespeichert …' : 'Speichern'),
          ),
        ],
      ),
    ),
  );
  Widget _field(
    TextEditingController c,
    String label,
    int length, {
    bool required = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      controller: c,
      enabled: !_busy,
      maxLength: length,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) =>
          required && (value ?? '').trim().isEmpty ? 'Bitte ausfüllen.' : null,
    ),
  );
}

String highlightDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
