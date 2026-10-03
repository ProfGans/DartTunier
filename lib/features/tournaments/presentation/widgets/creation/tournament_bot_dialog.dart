import 'package:flutter/material.dart';
import '../../../application/tournament_bot_factory.dart';
import '../../../domain/tournament_models.dart';

class TournamentBotDialog extends StatefulWidget {
  const TournamentBotDialog({
    super.key,
    required this.players,
    this.editPlayer,
  });
  final List<TournamentPlayer> players;
  final TournamentPlayer? editPlayer;
  @override
  State<TournamentBotDialog> createState() => _TournamentBotDialogState();
}

class _TournamentBotDialogState extends State<TournamentBotDialog> {
  late final name = TextEditingController(text: widget.editPlayer?.name ?? '');
  late final minimum = TextEditingController(
    text: '${widget.editPlayer?.bot?.targetAverage ?? 60}',
  );
  final maximum = TextEditingController(text: '70');
  final count = TextEditingController(text: '10');
  bool batch = false, busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    minimum.dispose();
    maximum.dispose();
    count.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final min = double.tryParse(minimum.text.replaceAll(',', '.'));
    final max = batch
        ? double.tryParse(maximum.text.replaceAll(',', '.'))
        : min;
    final amount = batch ? int.tryParse(count.text) : 1;
    if (min == null ||
        max == null ||
        amount == null ||
        !min.isFinite ||
        !max.isFinite ||
        min <= 0 ||
        max > 180 ||
        min > max ||
        amount < 1 ||
        amount > 128) {
      setState(
        () => error =
            'Bitte 1–128 Bots und einen gültigen Ziel-Average über 0 bis 180 eingeben. Von darf nicht größer als bis sein.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = widget.editPlayer != null
          ? [
              widget.editPlayer!.copyWith(
                name: name.text.trim().isEmpty
                    ? widget.editPlayer!.name
                    : name.text.trim(),
                bot: await TournamentBotFactory.resolve(min),
              ),
            ]
          : await TournamentBotFactory.create(
              count: amount,
              minimum: min,
              maximum: max,
              existingNames: widget.players
                  .expand((p) => p.individuals)
                  .map((p) => p.name),
              name: name.text,
            );
      if (mounted) Navigator.of(context).pop(result);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Bots konnten nicht erstellt werden. Bitte erneut versuchen.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(
    TextEditingController controller,
    String label, {
    bool numeric = true,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextField(
      controller: controller,
      enabled: !busy,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.editPlayer == null ? 'Bots hinzufügen' : 'Bot bearbeiten',
    ),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.editPlayer == null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mehrere Bots'),
                value: batch,
                onChanged: busy ? null : (v) => setState(() => batch = v),
              ),
            if (batch)
              field(count, 'Anzahl Bots')
            else
              field(name, 'Name (optional)', numeric: false),
            field(minimum, batch ? 'Ziel-Average von' : 'Ziel-Average'),
            if (batch) field(maximum, 'Ziel-Average bis'),
            const SizedBox(height: 12),
            Text(
              batch
                  ? 'Jeder Bot erhält einen zufälligen Ziel-Average innerhalb dieses Bereichs.'
                  : 'Die Stärke wird mit der Theo-Bot-Berechnung bestimmt.',
            ),
            const Text(
              'Der tatsächlich gespielte Average kann je Match abweichen.',
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
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
        onPressed: busy ? null : save,
        child: Text(
          busy
              ? 'Bots werden vorbereitet …'
              : widget.editPlayer == null
              ? 'Hinzufügen'
              : 'Speichern',
        ),
      ),
    ],
  );
}
