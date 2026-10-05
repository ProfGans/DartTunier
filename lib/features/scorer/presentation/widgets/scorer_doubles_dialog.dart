import 'package:flutter/material.dart';
import '../../../communities/data/supabase_community_repository.dart';

class ScorerDoublesDialog extends StatefulWidget {
  const ScorerDoublesDialog({
    super.key,
    required this.first,
    this.second = '',
    this.lockFirst = false,
    this.allowCommunity = false,
  });
  final String first, second;
  final bool lockFirst, allowCommunity;
  @override
  State<ScorerDoublesDialog> createState() => _ScorerDoublesDialogState();
}

class _ScorerDoublesDialogState extends State<ScorerDoublesDialog> {
  late final first = TextEditingController(text: widget.first);
  late final second = TextEditingController(text: widget.second);
  final form = GlobalKey<FormState>();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    first.dispose();
    second.dispose();
    super.dispose();
  }

  Future<void> _select(TextEditingController target) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final repository = SupabaseCommunityRepository();
      final communities = await repository.loadMyCommunities();
      if (!mounted) return;
      final id = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Community auswählen'),
          children: [
            if (communities.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Keine Communities gefunden.'),
              ),
            for (final c in communities)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, c.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(c.name),
                ),
              ),
          ],
        ),
      );
      if (id == null) return;
      final members = await repository.loadMembers(id);
      if (!mounted) return;
      final name = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Mitglied auswählen'),
          children: [
            if (members.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Keine Mitglieder gefunden.'),
              ),
            for (final m in members)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, m.displayName),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(m.displayName),
                ),
              ),
          ],
        ),
      );
      if (mounted && name != null) target.text = name;
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Community-Mitglieder konnten nicht geladen werden. Bitte erneut versuchen.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Doppelteam zusammenstellen'),
    content: SizedBox(
      width: 460,
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Zwei Spieler teilen sich einen Punktestand und werfen abwechselnd eine Aufnahme.',
            ),
            for (final entry in [(first, 1), (second, 2)]) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: entry.$1,
                readOnly: entry.$2 == 1 && widget.lockFirst,
                decoration: InputDecoration(
                  labelText: 'Spieler ${entry.$2} · lokaler Name',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Namen eingeben.';
                  }
                  if (entry.$2 == 2 &&
                      value.trim().toLowerCase() ==
                          first.text.trim().toLowerCase()) {
                    return 'Zwei verschiedene Spieler auswählen.';
                  }
                  return null;
                },
              ),
              if (widget.allowCommunity && !(entry.$2 == 1 && widget.lockFirst))
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _select(entry.$1),
                  icon: const Icon(Icons.groups_outlined),
                  label: const Text('Aus Community auswählen'),
                ),
            ],
            if (widget.allowCommunity)
              const Text(
                'Die Auswahl übernimmt den Namen. Eine Kontoanmeldung erfolgt weiterhin über die Spieleinladung.',
              ),
            if (error != null) Text(error!),
            if (busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        onPressed: busy
            ? null
            : () {
                if (form.currentState!.validate()) {
                  Navigator.pop(context, [
                    first.text.trim(),
                    second.text.trim(),
                  ]);
                }
              },
        child: const Text('Doppelteam übernehmen'),
      ),
    ],
  );
}
